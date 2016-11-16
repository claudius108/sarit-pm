xquery version "3.0";

module namespace app="http://www.tei-c.org/tei-simple/templates";

import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "pages.xql";
import module namespace tei-to-html="http://exist-db.org/xquery/app/tei2html" at "tei2html.xql";
import module namespace sarit="http://exist-db.org/xquery/sarit";
import module namespace metadata = "http://exist-db.org/ns/sarit/metadata/" at "metadata.xqm";

import module namespace console="http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";
import module namespace sarit-slp1 = "http://hra.uni-heidelberg.de/ns/sarit-transliteration";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $app:devnag2roman := doc($config:app-root || "/modules/transliteration-rules.xml")//*[@id = "devnag2roman"];
declare variable $app:roman2devnag := doc($config:app-root || "/modules/transliteration-rules.xml")//*[@id = "roman2devnag"];
declare variable $app:roman2devnag-search := doc($config:app-root || "/modules/transliteration-rules.xml")//*[@id = "roman2devnag-search"];
declare variable $app:expand := doc($config:app-root || "/modules/transliteration-rules.xml")//*[@id = "expand"];
declare variable $app:iast-char-repertoire-negation := '[^aābcdḍeĕghḥiïījklḷḹmṁṃnñṅṇoŏprṛṝsśṣtṭuüūvy0-9\s]';

declare
    %templates:wrap
function app:check-login($node as node(), $model as map(*)) {
    let $user := request:get-attribute("org.exist.tei-simple.user")
    return
        if ($user) then
            templates:process($node/*[2], $model)
        else
            templates:process($node/*[1], $model)
};

declare
    %templates:wrap
function app:current-user($node as node(), $model as map(*)) {
    request:get-attribute("org.exist.tei-simple.user")
};

declare
    %templates:wrap
function app:show-if-logged-in($node as node(), $model as map(*)) {
    let $user := request:get-attribute("org.exist.tei-simple.user")
    return
        if ($user) then
            templates:process($node/node(), $model)
        else
            ()
};

(:~
 : List documents in data collection
 :)
declare
    %templates:wrap
    %templates:default("order", "title")
function app:list-works($node as node(), $model as map(*), $filter as xs:string?, $browse as xs:string?,
    $order as xs:string) {
    let $cached := session:get-attribute("simple.works")
    let $filtered :=
        if ($filter) then
            let $ordered :=
                for $item in
                    ft:search($config:data-root, $browse || ":" || $filter, ("author", "title"))/search
                let $author := $item/field[@name = "author"]
                order by $author[1], $author[2], $author[3]
                return
                    $item
            for $doc in $ordered
            return
                doc($doc/@uri)/tei:TEI
        else if ($cached and $filter != "") then
            app:order-documents($cached, $order)
        else
            app:order-documents(collection($config:data-root)/tei:TEI, $order)
    return (
        session:set-attribute("simple.works", $filtered),
        session:set-attribute("browse", $browse),
        session:set-attribute("filter", $filter),
        map {
            "all" : $filtered
        }
    )
};

declare function app:order-documents($docs as element()*, $order as xs:string) {
    let $orderFunc :=
        switch ($order)
            case "author" return
                app:work-author#1
            case "lang" return
                app:work-lang#1
            default return
                app:work-title#1
    for $doc in $docs
    order by $orderFunc($doc)
    return
        $doc
};



declare
    %templates:wrap
    %templates:default("start", 1)
    %templates:default("per-page", 10)
function app:browse($node as node(), $model as map(*), $start as xs:int, $per-page as xs:int, $filter as xs:string?) {
    if (empty($model?all) and (empty($filter) or $filter = "")) then
        templates:process($node/*[@class="empty"], $model)
    else
        subsequence($model?all, $start, $per-page) !
            templates:process($node/*[not(@class="empty")], map:new(($model, map { "work": . })))
};

(:template function in view-work.html:)
declare function app:header($node as node(), $model as map(*)) {
    tei-to-html:render(root($model("data"))//tei:teiHeader)
};

declare
    %templates:wrap
function app:short-header($node as node(), $model as map(*)) {
    let $work := $model("work")/ancestor-or-self::tei:TEI
    let $id := util:document-name($work)
    let $view :=
        if (pages:has-pages($work)) then
            "page"
        else
            $config:default-view
    return
        $pm-config:web-transform($work/tei:teiHeader, map {
            "header": "short",
            "doc": $id || "?view=" || $view
        })
};

(:~
 : Create a bootstrap pagination element to navigate through the hits.
 :)
declare
    %templates:default('key', 'hits')
    %templates:default('start', 1)
    %templates:default("per-page", 10)
    %templates:default("min-hits", 0)
    %templates:default("max-pages", 10)
function app:paginate($node as node(), $model as map(*), $key as xs:string, $start as xs:int, $per-page as xs:int, $min-hits as xs:int,
    $max-pages as xs:int) {
    if ($min-hits < 0 or count($model($key)) >= $min-hits) then
        element { node-name($node) } {
            $node/@*,
            let $count := xs:integer(ceiling(count($model($key))) div $per-page) + 1
            let $middle := ($max-pages + 1) idiv 2
            return (
                if ($start = 1) then (
                    <li class="disabled">
                        <a><i class="glyphicon glyphicon-fast-backward"/></a>
                    </li>,
                    <li class="disabled">
                        <a><i class="glyphicon glyphicon-backward"/></a>
                    </li>
                ) else (
                    <li>
                        <a href="?start=1"><i class="glyphicon glyphicon-fast-backward"/></a>
                    </li>,
                    <li>
                        <a href="?start={max( ($start - $per-page, 1 ) ) }"><i class="glyphicon glyphicon-backward"/></a>
                    </li>
                ),
                let $startPage := xs:integer(ceiling($start div $per-page))
                let $lowerBound := max(($startPage - ($max-pages idiv 2), 1))
                let $upperBound := min(($lowerBound + $max-pages - 1, $count))
                let $lowerBound := max(($upperBound - $max-pages + 1, 1))
                for $i in $lowerBound to $upperBound
                return
                    if ($i = ceiling($start div $per-page)) then
                        <li class="active"><a href="?start={max( (($i - 1) * $per-page + 1, 1) )}">{$i}</a></li>
                    else
                        <li><a href="?start={max( (($i - 1) * $per-page + 1, 1)) }">{$i}</a></li>,
                if ($start + $per-page < count($model($key))) then (
                    <li>
                        <a href="?start={$start + $per-page}"><i class="glyphicon glyphicon-forward"/></a>
                    </li>,
                    <li>
                        <a href="?start={max( (($count - 1) * $per-page + 1, 1))}"><i class="glyphicon glyphicon-fast-forward"/></a>
                    </li>
                ) else (
                    <li class="disabled">
                        <a><i class="glyphicon glyphicon-forward"/></a>
                    </li>,
                    <li>
                        <a><i class="glyphicon glyphicon-fast-forward"/></a>
                    </li>
                )
            )
        }
    else
        ()
};

(:~
    Create a span with the number of items in the current search result.
:)
declare
    %templates:wrap
    %templates:default("key", "hitCount")
function app:hit-count($node as node()*, $model as map(*), $key as xs:string) {
    let $value := $model?($key)
    return
        if ($value instance of xs:integer) then
            $value
        else
            count($value)
};

declare 
    %templates:wrap
function app:checkbox($node as node(), $model as map(*), $target-texts as xs:string*) {
    let $id := $model("work")/@xml:id/string()
    return (
        attribute { "value" } {
            $id
        },
        if ($id = $target-texts) then
            attribute checked { "checked" }
        else
            ()
    )
};

declare function app:statistics($node as node(), $model as map(*)) {
        "SARIT currently contains "|| $metadata:metadata/metadata:number-of-xml-works ||" text files (TEI-XML) of " || $metadata:metadata/metadata:size-of-xml-works || " XML (" || $metadata:metadata/metadata:number-of-pdf-pages || " pages in PDF format)."
};

declare %public function app:work-author($work as element(tei:TEI)?) {
    let $work-commentators := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[@role eq 'commentator']/text()
    let $work-authors := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[@role eq 'base-author']/text()
    let $work-authors := if ($work-authors) then $work-authors else $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author/text()
    let $work-authors := if ($work-commentators) then $work-commentators else $work-authors
    let $work-authors := if ($work-authors) then tei-to-html:serialize-list($work-authors) else ()
    return 
        $work-authors    
};

declare function app:work-author($node as node(), $model as map(*)) {
    let $work := $model("work")/ancestor-or-self::tei:TEI
    let $work-commentators := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[@role eq 'commentator']/text()
    let $work-authors := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[@role eq 'base-author']/text()
    let $work-authors := if ($work-authors) then $work-authors else $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author/text()
    let $work-authors := if ($work-commentators) then $work-commentators else $work-authors
    let $work-authors := if ($work-authors) then tei-to-html:serialize-list($work-authors) else ()
    return 
        $work-authors    
};

declare function app:work-lang($node as node(), $model as map(*)) {
    let $work := $model("work")/ancestor-or-self::tei:TEI
    return
        app:work-lang($work)
};

declare function app:work-lang($work as element(tei:TEI)) {
    let $script := $work//tei:text/@xml:lang
    let $script := if ($script eq 'sa-Latn') then 'IAST' else 'Devanagari'
    let $auto-conversion := $work//tei:revisionDesc/tei:change[@type eq 'conversion'][@subtype eq 'automatic'] 
    return 
        concat($script, if ($auto-conversion) then ' (automatically converted)' else '')  
};


(:~
 :
 :)
declare function app:work-title($node as node(), $model as map(*), $type as xs:string?) {
    let $suffix := if ($type) then "." || $type else ()
    let $work := $model("work")/ancestor-or-self::tei:TEI
    let $id := util:document-name($work)
    let $view :=
        if (pages:has-pages($work)) then
            "page"
        else
            $config:default-view
    return
        <a href="{$node/@href}{$id}{$suffix}?view={$view}">{ app:work-title($work) }</a>
};

declare %public function app:work-title($work as element(tei:TEI)?) {
    let $mainTitle :=
        (
            $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type = "main"]/text(),
            $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1]/text()
        )[1]
    let $subTitles := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type = "sub"][@subtype = "commentary"]
    return
        if ($subTitles) then
            string-join(( $mainTitle, ": ", string-join($subTitles, " and ") ))
        else
            $mainTitle
};

declare function app:download-link($node as node(), $model as map(*), $type as xs:string, $doc as xs:string?,
    $source as xs:boolean?) {
    let $file :=
        if ($model?work) then
            replace(util:document-name($model("work")), "^(.*?)\.[^\.]*$", "$1")
        else
            replace($doc, "^(.*)\..*$", "$1")
    let $uuid := util:uuid()
    return
        element { node-name($node) } {
            $node/@*,
            attribute data-token { $uuid },
            attribute href { $node/@href || $file || "." || $type || "?token=" || $uuid || "&amp;cache=no"
                || (if ($source) then "&amp;source=yes" else ())
            },
            $node/node()
        }
};

declare
    %templates:wrap
function app:fix-links($node as node(), $model as map(*)) {
    app:fix-links(templates:process($node/node(), $model))
};

declare function app:fix-links($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(a) | element(link) return
                (: skip links with @data-template attributes; otherwise we can run into duplicate @href errors :)
                if ($node/@data-template) then
                    $node
                else
                    let $href :=
                        replace(
                            $node/@href,
                            "\$app",
                            (request:get-context-path() || substring-after($config:app-root, "/db"))
                        )
                    return
                        element { node-name($node) } {
                            attribute href {$href}, $node/@* except $node/@href, app:fix-links($node/node())
                        }
            case element() return
                element { node-name($node) } {
                    $node/@*, app:fix-links($node/node())
                }
            default return
                $node
};

(: Search :)

declare function app:work-authors($node as node(), $model as map(*)) {
    let $authors := distinct-values(collection($config:data-root)//tei:fileDesc/tei:titleStmt/tei:author)
    let $authors := for $author in $authors order by translate($author, 'ĀŚ', 'AS') return $author
    let $control :=
        <select multiple="multiple" name="work-authors" class="form-control">
            <option value="all" selected="selected">In Texts By Any Author</option>
            {for $author in $authors
            return <option value="{$author}">{$author}</option>
            }
        </select>
    return
        templates:form-control($control, $model)
};

(:~
: Execute the query. The search results are not output immediately. Instead they
: are passed to nested templates through the $model parameter.
:
: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @param $node
: @param $model
: @param $query The query string. This string is transformed into a <query> element containing one or two <bool> elements in a Lucene query and it is transformed into a sequence of one or two query strings in an ngram query. The first <bool> and the first string contain the query as input and the second the query as transliterated into Devanagari or IAST as determined by $query-scripts. One <bool> and one query string may be empty.
: @param $index The index against which the query is to be performed, as the string "ngram" or "lucene".
: @param $tei-target A sequence of one or more targets within a TEI document, the tei:teiHeader or tei:text.
: @param $work-authors A sequence of the string "all" or of the xml:ids of the documents associated with the selected authors.
: @param $query-scripts A sequence of the string "all" or of the values "sa-Latn" or "sa-Deva", indicating whether or not the user wishes to transliterate the query string.
: @param $target-texts A sequence of the string "all" or of the xml:ids of the documents selected.

: @return The function returns a map containing the $hits, the $query, and the $query-scope. The search results are output through the nested templates, app:hit-count, app:paginate, and app:show-hits.
:)
(:template function in search.html:)
declare
    %templates:default("index", "lucene")
    %templates:default("tei-target", "tei-text")
    %templates:default("query-scope", "narrow")
    %templates:default("work-authors", "all")
    %templates:default("query-scripts", "all")
    %templates:default("target-texts", "all")
    %templates:default("bool", "new")
function app:query($node as node()*, $model as map(*), $query as xs:string?, $index as xs:string, $tei-target as xs:string+, $query-scope as xs:string, $work-authors as xs:string+, $query-scripts as xs:string, $target-texts as xs:string+, $bool as xs:string) as map(*) {
    let $query := normalize-space($query)
    return
        (:First, which documents to query against has to be found out. Users can either make no selections in the list of documents, passing the value "all", or they can select individual document, passing a sequence of their xml:ids in $target-texts. Users can also select documents based on their authors. If no specific authors are selected, the value "all" is passed in $work-authors, but if selections have been made, a sequence of their xml:ids is passed. :)
        (:$target-texts will either have the value 'all' or contain a sequence of document xml:ids.:)
        let $target-texts := 'all'
        (:After it has been determined which documents to query, we have to find out which document parts are targeted, the query "context". There are two parts, the text element ("tei-text") and the TEI header ("tei-header"). It is possible to select multiple contexts:)
        let $context := collection($config:data-root)/tei:TEI
        (: Here the actual query commences. This is split into two parts, the first for a Lucene query and the second for an ngram query. :)
        (:The query passed to a Lucene query in ft:query is a string containing one or two queries joined by an OR. The queries contain the original query and the transliterated query, as indicated by the user in $query-scripts.:)
	let $options := <options>
                              <default-operator>and</default-operator>
                              <phrase-slop>0</phrase-slop>
                              <leading-wildcard>yes</leading-wildcard>
			      <lowercase-expanded>no</lowercase-expanded>
                              <filter-rewrite>yes</filter-rewrite>
                        </options>
	(: TODO: fix slp1 transcoder so that we don't have to replace [ and ] here. :)
	let $query := fn:replace(sarit-slp1:transcode($query), "\[|\]", "")
	let $hits :=
	for $hit in (
		$context//tei:p[ft:query(., $query, $options)],
		$context//tei:lg[ft:query(., $query, $options)],
		$context//tei:l[not(local-name(./..) eq 'lg')][ft:query(., $query, $options)],
		$context//tei:trailer[ft:query(., $query, $options)],
		$context//tei:head[ft:query(., $query, $options)]
	)
	order by ft:score($hit) descending
        return $hit
	
        (:gather up previous searches for match highlighting.:)
        (:NB: lucene-queries may have slashes added, so they may be different from ngram-queries:)
        let $lucene-query := $query
	let $log := util:log("info", $query)
        return
        (: The hits are not returned directly, but processed by the nested templates :)
        map {
                "hits" : $hits,
                "hitCount": count($hits),
                "ngram-query" : 'get lost',
                "lucene-query" : $lucene-query
        }
};


declare function app:expand-hits($divs as element()*, $index as xs:string) {
    let $queries :=
        switch($index)
            case "ngram" return
                session:get-attribute("apps.sarit.ngram-query")
            default return
                session:get-attribute("apps.sarit.lucene-query")
    for $div in $divs
    for $query in distinct-values($queries)
    let $result := 
        switch ($index)
            case "ngram" return
                $div[ngram:wildcard-contains(., $query)]
            default return
                $div[ft:query(., $query)]
    return
        util:expand($result, "add-exist-id=all")
};

(:~
    Output the actual search result as a div, using the kwic module to summarize full text matches.
:)
declare
    %templates:wrap
    %templates:default("start", 1)
    %templates:default("per-page", 10)
    %templates:default("index", "ngram")
function app:show-hits($node as node()*, $model as map(*), $start as xs:integer, $per-page as xs:integer, $view as xs:string?,
    $index as xs:string) {
    let $view := if ($view) then $view else $config:default-view
    for $hit at $p in subsequence($model("hits"), $start, $per-page)
    let $parent := $hit/ancestor-or-self::tei:div[1]
    let $parent := if ($parent) then $parent else $hit/ancestor-or-self::tei:teiHeader
    let $parent := if ($parent) then $parent else root($hit)
    let $div := app:get-current($parent)
    let $parent-id := util:document-name($parent) || "?root=" || util:node-id($parent)
    let $div-id := util:document-name($div) || "?root=" || util:node-id($div)
    (:if the nearest div does not have an xml:id, find the nearest element with an xml:id and use it:)
    (:is this necessary - can't we just use the nearest ancestor?:)
(:    let $div-id := :)
(:        if ($div-id) :)
(:        then $div-id :)
(:        else ($hit/ancestor-or-self::*[@xml:id]/@xml:id)[1]/string():)
    (:if it is not a div, it will not have a head:)
    let $div-head := $parent/tei:head/text()
    (:TODO: what if the hit is in the header?:)
    let $work := $hit/ancestor::tei:TEI
    let $work-title := app:work-title($work)
    (:the work always has xml:id.:)
    let $work-id := $work/@xml:id/string()
    let $work-id := util:document-name($work)

    let $loc :=
        <tr class="reference">
            <td colspan="3">
                <span class="number">{$start + $p - 1}</span>
                <span class="headings">
                    <a href="{$work-id}">{$work-title}</a>{if ($div-head) then ' / ' else ''}<a href="{$parent-id}&amp;action=search">{$div-head}</a>
                </span>
            </td>
        </tr>
    let $expanded := util:expand($hit, "add-exist-id=all")
    return (
        $loc,
        for $match in subsequence($expanded//exist:match, 1, 5)
        let $matchId := $match/../@exist:id
        let $docLink :=
            if ($view = "page") then
                let $contextNode := util:node-by-id($div, $matchId)
                let $page := $contextNode/preceding::tei:pb[1]
                return
                    util:document-name($work) || "?root=" || util:node-id($page)
            else
                $div-id
        let $link := $docLink || "&amp;action=search&amp;view=" || $view || "&amp;index=" || $index || "#" || $matchId
        let $config := <config width="60" table="yes" link="{$link}"/>
        let $kwic := kwic:get-summary($expanded, $match, $config)
        let $output :=
            if ($index = "ngram" and contains($model?ngram-query, "*")) then
                <tr>
                    <td colspan="3" class="text">
                        {
                            <span class="previous">{normalize-space($kwic//td[@class = "previous"]/node())}</span>,
                            <a href="{$link}"><i class="material-icons">play_arrow</i></a>,
                            <span class="hi">{normalize-space($kwic//td[@class = "hi"]//text())}</span>,
                            <span class="following">{normalize-space($kwic//td[@class = "following"]/node())}</span>
                        }
                    </td>
                </tr>
            else
                $kwic
        return $output
    )
};

declare %private function app:get-current($div as element()?) {
    if (empty($div)) then
        ()
    else
        if ($div instance of element(tei:teiHeader)) then
        $div
        else
            if (
                empty($div/preceding-sibling::tei:div)  (: first div in section :)
                and count($div/preceding-sibling::*) < 5 (: less than 5 elements before div :)
                and $div/.. instance of element(tei:div) (: parent is a div :)
            ) then
                pages:get-previous($div/..)
            else
                $div
};

import module namespace m='http://www.tei-c.org/tei-simple/models/teisimple.odd/latex' at '/db/apps/sarit-pm/transform/teisimple-latex.xql';

declare variable $xml external;

declare variable $parameters external;

let $options := map {
    "image-dir": (system:get-exist-home() || "/webapp/WEB-INF/data/expathrepo/tei-simple-1.0/test/", system:get-exist-home() || "/webapp/WEB-INF/data/expathrepo/tei-simple-1.0/doc/"),
    "styles": ["../transform/teisimple.css"],
    "collection": "/db/apps/sarit-pm/transform",
    "parameters": if (exists($parameters)) then $parameters else map {}
}
return m:transform($options, $xml)
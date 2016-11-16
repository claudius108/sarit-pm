$( document ).ready(function() {
    // console.log("Document ready");
    var hkToIastHK = ["A", "I", "U", "R", "RR", "lR", "lRR", "M", "H", "G", "J", "N", "z", "S"];
    var hkToIastIAST = ["ā", "ī", "ū", "ṛ", "ṝ", "ḷ", "ḹ", "ṃ", "ḥ", "ṅ", "ñ", "ṇ", "ś", "ṣ"];
    var hkToIastIgnore = ["OR", "AND", "NOT", ];
    function hkToIast(someString) {
	// map someString to iast
	var result = someString;
	// avoiding keywords
	if (hkToIastIgnore.indexOf(someString) == -1) {
	    result = someString.replace(/(?:(?:lR|[Rl])R|[AG-JMNRSUz])/g,
					function (x)
					{
					    // console.log("looking for ", x);
					    // console.log("Index: ", hkToIastHK.indexOf(x));
					    return hkToIastIAST[hkToIastHK.indexOf(x)];
					});
	} else {};
	
	return result;
    }
    // select input fields to enable conversion for
    $( "input[type='text']" ).add("input[type='search']").on(
    "change",// on a change event
	function( eventObject ) { // rewrite the value
	    // eventObject.preventDefault();
	    // console.log("Text is now: ", $(this).val() );
	    $(this).val(
		// split current value, apply transliteration, and join again
		$(this).val().split(" ").map(hkToIast).join(" ")
	    );
	});
});

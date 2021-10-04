Satisfactory Recipe Analysis
============================

Good for designing new custom recipes and trying to balance them. Also for analyzing alternate recipes.


* <label><input type=radio name=machine value=constructor checked>Constructor</label>
* <label><input type=radio name=machine value=smelter>Smelter</label>
* <label><input type=radio name=machine value=assembler>Assembler</label>
* <label><input type=radio name=machine value=foundry>Foundry</label>
* <label><input type=radio name=machine value=refinery>Refinery</label>
* <label><input type=radio name=machine value=manufacturer>Manufacturer</label>
{: .optionset}

<form id=recipe></form>

* <label><input type=radio name=recipefilter value=firstoutput checked>Produces first output</label>
* <label><input type=radio name=recipefilter value=anyoutput>Produces any output</label>
* <label><input type=radio name=recipefilter value=samemachine>Same machine</label>
{: .optionset}

Recipe | Machine | Inputs | Outputs | Rate | Sink value | Energy | MJ/item
-------|---------|--------|---------|------|------------|--------|---------
 |
{: #recipes}

<!-- One of these works on Sikorsky, one works on GH Pages. The other will 404 either way. -->
<script type=module src="/static/satisfactory-recipes.js"></script>
<script type=module src="satisfactory-recipes.js"></script>
<script>console.warn("Expected one (but not two) 404 errors loading JavaScript files")</script>

<style>
#recipe table tr td:not(:first-child) {width: 100%;}
#recipes {width: 100%;}
ul.optionset {list-style-type: none; display: flex; padding-left: 0;}
ul.optionset li {list-style-image: none;}
tr.yourrecipe {background: #cfe !important;}
#recipes th {cursor: pointer;}
.container {max-width: unset;} /* Disable the narrowing of the window by my GH Pages theme */
</style>

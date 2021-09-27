Satisfactory Recipe Analysis
============================

TODO:
- Compare against best and worst for that building type
- Compare against other things that produce the same outputs
- For current and comparison recipes, show sink ratio, energy ratio (if applicable), MJ/item cost, and throughput (items/min).
- Comparison recipes that produce additional outputs should show those in a separate column
- For extractors, show sink points per minute and per MJ, for each possible resource node purity?

Good for designing new custom recipes and trying to balance them. Also for analyzing alternate recipes.


* <label><input type=radio name=machine value=constructor checked>Constructor</label>
* <label><input type=radio name=machine value=assembler>Assembler</label>
* <label><input type=radio name=machine value=refinery>Refinery</label>

<form id=recipe></form>

<!-- One of these works on Sikorsky, one works on GH Pages. The other will 404 either way. -->
<script type=module src="/static/satisfactory-recipes.js"></script>
<script type=module src="satisfactory-recipes.js"></script>

<style>
table tr td:not(:first-child) {width: 100%;}
</style>

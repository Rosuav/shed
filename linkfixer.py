# Broken link finder/fixer
# 1. Starting with a given page, scan for all references
#    <* href="..."> mainly <a> but also <link>
#    <* src="..."> eg img, script, style
#    Anything else?
# 2. If ref is external (http:// or https:// and not gsarchive.net), record
#    the domain name in case there's a different sort of error. A separate
#    pass to validate external links will be of value, but should be cached
#    aggressively.
# 3. If ref is unnecessarily-external (pointing to gsarchive.net), autofix
#    to relative.
# 4. If ref is internal and the file exists, queue the target for scanning,
#    if not already queued or scanned.
# 5. If ref is internal and not found:
#    a. <nothing here yet - cf "is it an elephant">
#    b. Log the failure
# 6. Progressively go through the log and add autofixers

#!/usr/local/bin/io

path := Directory currentWorkingDirectory

writeln("")
writeln("Collecting files at ", path)
writeln("")

Directory with(path) files foreach(sourceFile,

	if (sourceFile name pathExtension != "h", continue)

	## Prepare property rewriting regex

	# We use (?:(?!\\*/).)+? and not .+?, to ensure we match just a single  
	# comment and we support '/' and '*' inside comments. This way, we skip 
	# /** Something */ and match only /** Documentation and/or more */ as a 
	# property comment in:
	#
	# /** Something */ 
	#
	# /** Documentation and/or more */
	# @property
	#
	# Use regex101.com to test (\/\*\*(?:(?!\*\/).)+?\*\/\n)?@property \(.+?\) (\w+(?: \*+)?(?: \<\w+\>)?) ?(\w+)
	#
	regex := Regex with("(\\/\\*\\*(?:(?!\\*/).)+?\\*\\/\\n)?@property \\(.+?\\) (\\w+(?: \\*+)?(?: \\<\\w+\\>)?) ?(\\w+);") dotAll
	matches := regex matchesIn(sourceFile contents)

	## Print regex captures

	writeln("")
	writeln(" ===  " .. (sourceFile path) .. " === ")
	writeln("")

	matches foreach(match, 
		match captures println
	)

	writeln("")

	## Replace regex captures by accessors

	output := Sequence clone asMutable
	slices := matches splitString
	output appendSeq(slices first)

	for(i, 0, matches all size - 1,

		match := matches at(i)
		doc := match captures at(1)
		getter := match expandTo(" - ($2)$3;")
		setter := nil
		
		type := match captures at(2)
		arg := match captures at(3)

		match string containsSeq("readonly") ifFalse(
			"Found setter" println
			setter = " - (void)set" .. (arg asCapitalized) .. ": (" .. type .. ")" .. arg .. ";"
			setter println
		)
		
		if (doc == nil, doc = "")

		output appendSeq(doc)
		output appendSeq(getter)
		setter ifNonNil(
			output appendSeq("\n")
			output appendSeq(doc)
			output appendSeq(setter)
		)
		output appendSeq(slices at(i + 1))
	)

	## Write the rewrite result

	sourceFile setContents(output)
)

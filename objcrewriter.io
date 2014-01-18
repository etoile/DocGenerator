#!/usr/local/bin/io

path := Directory currentWorkingDirectory

writeln("")
writeln("Collecting files at ", path)
writeln("")

Directory with(path) files foreach(sourceFile,

	if (sourceFile name pathExtension != "h", continue)

	# Prepare property rewriting regex

	#"(/\\*\\*.+?\\*/\\n)?@property \\(.+?\\) (\\w+(?: \\*+)?)(\\w+);"
	#"(/\\*\\*[^*/]+?\\*/\\n)?@property \\(.+?\\) (\\w+(?: \\*+)?)(\\w+);"

	regex := Regex with("(/\\*\\*(?:[^*]|\\*[^/])+?\\*/\\n)?@property \\(.+?\\) (\\w+(?: \\*+)?)(\\w+);")
	matches := regex matchesIn(sourceFile contents)

	# Print regex captures

	writeln("")
	writeln(" ===  " .. (sourceFile path) .. " === ")
	writeln("")

	matches foreach(match, 
		match captures println
	)

	writeln("")

	# Replace regex captures by accessors

	output := Sequence clone asMutable
	slices := matches splitString
	output appendSeq(slices first)

	for(i, 0, matches all size - 1,

		match := matches at(i)
		doc := match captures at(1)
		getter := match expandTo(" - ($2)$3;\n")
		setter := nil
		
		type := match captures at(2)
		arg := match captures at(3)

		match string containsSeq("readonly") ifFalse(
			setter = " - (void)set" .. (arg asCapitalized) .. ": (" .. type .. ")" .. arg .. ";\n"
		)
		
		output appendSeq(doc)
		output appendSeq(getter)
		ifNonNil(setter, 
			output appendSeq(doc)
			output appendSeq(setter)
		)
		output appendSeq(slices at(i + 1))
	)

	# Write the rewrite result

	sourceFile setContents(output)
)

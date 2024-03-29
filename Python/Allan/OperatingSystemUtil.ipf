// Use modern global access method, strict compilation
#pragma rtGlobals=3	

#pragma ModuleName = ModOperatingSystemUtil
#include ":ErrorUtil"

// XXX TODO README:
// (1) python2.7
// (2) anaconda
// (3) on path!
//	(3a)	-- binary must be at:
//		Windows: "C:/Program Files/Anaconda2/python"
//		os x       : "//anaconda/bin/python"
//

Structure RuntimeMetaInfo
	String path_to_research_directory
       String path_to_input_file
	String path_to_python_binary
EndStructure


Static Function /S sanitize_path(igor_path)
	// Igor is evil and uses colons, defying decades of convention for paths. This function helps S
	//
	// Args:
	//		igor_path: the (raw) path to sanitize
	// Returns:
	//		the path as a string
	String igor_path
	if (!running_windows())
		igor_path = ModOperatingSystemUtil#sanitize_mac_path_for_igor(igor_path)
	else
		igor_path = ModOperatingSystemUtil#to_igor_path(igor_path)
	endif
	return igor_path
End Function

Static Function read_csv_to_path(basename,igor_path,[first_line])
	// reads a (simple) csv file into a wave specified 
	// Args:
	//		basename: the wave to read into; starts with <basename>0
	//		igor_path: the igor-style path to the file to read in
	//		first_line: skip the first y-1 lines
	// Returns;
	//		nothing, but reads each column of the wave into <basename><0,1,2,...>
	// Q: quiet
	// J: delimited text
	// D: doouble precision
	// K=1: all columns are numeric 
	// /L={x,y,x,x}: skip first y-1 lines
	// /A=<z>: auto name, start with "<z>0" and work up
	String basename, igor_path
	Variable first_line
	first_line = ParamIsDefault(first_line) ? 1 : first_line
	LoadWave/Q/J/D/K=1/L={0,first_line,0,0,0}/A=$(basename) igor_path	
End Function

Static Function execute_python(PythonCommand)
	// executes a python command, given the options
	//
	// Args:
	//	 	PythonCommand: the string to use 
	// Returns:
	//		nothing; throws an error if it finds one.
	String PythonCommand
	ModOperatingSystemUtil#assert_python_binary_accessible()
	// POST: we can for sure call the python binary
	ModOperatingSystemUtil#os_command_line_execute(PythonCommand)
End Function

Static Function /S append_argument(Base,Name,Value,[AddSpace])
	// Function that appends "-<Name> <Value>" to Base, possible adding a space to the end
	//
	// Args:
	//		Base: what to add to
	//		Name: argument name
	//		Value: value of the argument
	//		AddSpace: optional, add a space. Defaults to retur
	// Returns:
	//		appended Base
	String & Base
	String Name,Value
	Variable AddSpace
	String Output
	AddSpace = ParamIsDefault(AddSpace) ? 1 : AddSpace
	sprintf Output,"-%s %s",Name,Value
	Base = Base + Output
	if (AddSpace)
		Base = Base + " "
	EndIf
End Function


Function running_windows() 
	// Flag for is running windows
	//
	// Returns:
	//		1 if windows, 0 if mac
	String platform = UpperStr(IgorInfo(2))
	Variable pos = strsearch(platform,"WINDOWS",0)
	return pos >= 0
End

Static Function /S python_binary_string()
	// Returns string for running python given this OS
	//
	// Returns:
	//		1 if windows, 0 if mac
	if (running_windows())
		return "C:/Users/dedwards/Anaconda2/python"
	else
		return "//anaconda/bin/python"
	endif
End Function


Static Function assert_python_binary_accessible()
	// Function which checks that python is accessible; if not, it throws an error.
	//
	//	Args:
	//		None
	//	Returns:
	//		None, interrupts execution if things are broken.
	String Command
	String binary = ModOperatingSystemUtil#python_binary_string()
	// according to python -h:
	// -V     : print the Python version number and exit (also --version)
	sprintf Command,"%s --version",binary
	// We want to do our own error handling
	Variable V_Flag = os_command_line_execute(Command,throw_error_if_failed=0)	
	String err
	sprintf err,"Python binary is inaccessible where we expect it (%s)", binary
	ModErrorUtil#Assert(V_Flag == 0,msg=err)
End Function

Static Function os_command_line_execute(execute_string,[throw_error_if_failed,pause_after])
	// executes a given string according to how the OS wants it (
	// ie: command-prompt style for windows or bashstyle for OS X)
	//
	// Args:
	//		execute_string: body of the command
	//		throw_error_if_failed: if true, throws an error if
	//		the command goes poorly. Defaults to true
	//		
	//		pause_after: if true, pauses excution after (XXX windows only)
	// Returns:
	//		V_flag, see ExecuteScriptText
	//
	String execute_string
	Variable throw_error_if_failed,pause_after
	throw_error_if_failed = ParamIsDefault(throw_error_if_failed) ? 1 : throw_error_if_failed
	pause_after = ParamIsDefault(pause_after) ? 0 : pause_after

	String Command
	if (!running_windows())
		// Pass to mac scripting system
		sprintf Command,"do shell script \"%s\"",execute_string
	else
		// Pass to windows command prompt
		sprintf Command,"%s",execute_string
	endif	
	// UNQ: remove leading and trailing double-quote (only for mac)
	print(Command)
	ExecuteScriptText /Z Command
	if (throw_error_if_failed)
		// according to ExecuteScriptText:
		// If the /Z flag is used then a variable named V_flag is
		// created and is set to a nonzero value if an error was generated by the script or zero if no error. 
		ModErrorUtil#Assert(V_flag == 0,msg="executing " + Command + " failed with return:"+S_Value)
	endif
	return V_flag
End Function

Static Function /S replace_double(needle,haystack)
	// replaces double-instances of a needle in haystaack with a single instance
	//
	// Args:
	//		needle : what we are looking for
	//		haystack: what to search for
	// Returns:
	//		unix_style, compatible with (e.g.) GetFileFolderInfo
	//
	String needle,haystack
	return ReplaceString(needle + needle,haystack,needle)
End Function

Static Function /S to_igor_path(unix_style)
	// convers a unix-style path to an igor-style path
	//
	// Args:
	//		unix_style : absolute path to sanitize
	// Returns:
	//		unix_style, compatible with (e.g.) GetFileFolderInfo
	//
	String unix_style
	String with_colons = ReplaceString("/",unix_style,":")
	// Igor doesnt want a leading colon for an absolute path
	if (strlen(with_colons) > 1 && (cmpstr(with_colons[0],":")== 0))
		with_colons = with_colons[1,strlen(with_colons)]
	endif
	return replace_double(":",with_colons)
End Function

Static Function /S sanitize_path_for_windows(path)
	// Makes an absolute path windows-compatible.
	//
	// Args:
	//		path : absolute path to sanitize
	// Returns:
	//		path, with leading /c/ or c/ replaced by "C:/"
	//
	String path
	Variable n = strlen(path) 
	if (GrepString(path[0],"^/"))
		path = path[1,n]
	endif
	// POST: no leading /
	return replace_start("c/",path,"C:/")
End Function

Static Function /S replace_start(needle,haystack,replace_with)
	// Replaces a match of a pattern at the start of a string
	//
	// Args:
	//		needle : pattern we are looking for at the start
	//		haystack : the string we are searching in
	//		replace_with: what to replace needle with, if we find it
	// Returns:
	//		<haystack>, with <needle> replaced by <replace_with>, if we find it. 
	String needle,haystack,replace_with
	Variable n_needle = strlen(needle)
	Variable n_haystack = strlen(haystack)
	if ( (GrepString(haystack,"^" + needle)))
		haystack = replace_with + haystack[n_needle,n_haystack]
	endif 
	return haystack
End Function

Static Function /S sanitize_windows_path_for_igor(path)
	// Makes an absolute windows-style path igor compatible
	//
	// Args:
	//		path : absolute path to sanitize
	// Returns:
	//		path, with leading "C:/" replaced by /c/ 
	//
	String path
	return replace_start("C:/",path,"/c/")
End Function

Static Function /S sanitize_mac_path_for_igor(path)
	// Makes an absolute windows-style path igor compatible
	//
	// Args:
	//		path : absolute path to sanitize
	// Returns:
	//		path, with leading "C:/" replaced by /c/ 
	//
	String path
	String igor_path = ModOperatingSystemUtil#to_igor_path(path)
	igor_path = "Macintosh HD:" + igor_path
	// replace possible double colons
	igor_path = ModOperatingSystemUtil#replace_double(":",igor_path)
	return igor_path
End Function


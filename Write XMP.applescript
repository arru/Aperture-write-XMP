property tempExportFolder : (POSIX file "/tmp/Aperture-XMP/")
property sqlCommand : "/usr/bin/sqlite3 "
property reasonablePathLength : 6

property apertureSidecarExtension : "XMP"
property darktableSidecarExtension : "xmp"
property exportedKeyword : "DarkTable"

--property aperturExportImageSetting : "JPEG - Fit within 640 x 640"
global apertureLibPath
tell application "System Events" to set apertureLibPath to value of property list item "LibraryPath" of property list file ((path to preferences as Unicode text) & "com.apple.aperture.plist")

assert against length of apertureLibPath < 12 given message:"Can't find aperture library. Try hard-coding its path into the script."
--	set apertureLibPath to "/Users/Chtulu/Pictures/Aperture Library.aplibrary"
log apertureLibPath

-- Main script flow --

--create temporary export folder and verify that it exists
do shell script "mkdir -p " & quoted form of (POSIX path of tempExportFolder)

set tempFolderExists to false
try
	do shell script "test ! -d " & quoted form of (POSIX path of tempExportFolder)
on error errStr number errorNumber
	-- test writes its output to stderr
	if errorNumber = 1 then
		-- 1 = folder exists
		set tempFolderExists to true
	else
		error errStr number errorNumber
	end if
end try

assert against not tempFolderExists given message:"Could not create temporary folder at " & (POSIX path of tempExportFolder)

tell application "Aperture" to set imageSel to (get selection)

if imageSel is {} then
	error "Please select one or more images."
end if

set numOffline to 0
set numManaged to 0

--check if selected images are offline, or still managed, before going any further

tell application "Aperture"
	repeat with i from 1 to count of imageSel
		tell item i of imageSel
			if online is false then
				set numOffline to numOffline + 1
			end if
			
			if referenced is false then
				set numManaged to numManaged + 1
			end if
		end tell
	end repeat
end tell

if numOffline > 0 then
	error (numOffline as string) & " images are offline (on a storage device not connected). Please connect it and try again"
else if numManaged > 0 then
	error (numManaged as string) & " images are still managed by Aperture. It's a bad idea to mess around inside the Aperture library, so this script requires all selected images to be referenced to somewhere outside of the Aperture library. Relocate your originals and try again."
end if

set numFalselyTagged to 0
set numSkippedMovies to 0
set numAlreadyExported to 0

set numRemaining to count of imageSel
set numSidecarsWritten to 0
set currentImageName to "(before first image)"

-- main export loop

try
	repeat with i from 1 to count of imageSel
		
		set currentImage to item i of imageSel
		set currentImageName to name of currentImage as string
		
		set masterPath to getMasterImagePath from currentImage
		set master to POSIX file masterPath as alias
		assertFileExists at masterPath given message:"Master file for " & currentImageName & " at " & masterPath & " does not exist"
		
		-- speed things up a bit by not writing sidecars for movies, because DarkTable ignores them anyway
		if checkIfMovie for master then
			set numSkippedMovies to numSkippedMovies + 1
		else
			tell application "Finder"
				set exportFolder to (parent of master)
				set exportFolderPath to POSIX path of (exportFolder as alias)
				set fileName to name of master
			end tell
			
			-- DarkTable happens to expect image.JPG.xmp style sidecar naming
			-- The standard specifies image.xmp style naming, so other apps might expect that scheme instead
			set sidecarDestination to exportFolderPath & fileName & "." & darktableSidecarExtension
			set sidecarAlreadyPresent to checkFileExists at sidecarDestination
			
			if sidecarAlreadyPresent then
				--	sidecar already exists
				set numAlreadyExported to numAlreadyExported + 1
			else
				tell application "Aperture" to set hasKeyword to (exportedKeyword is in keywords of currentImage)
				--has keyword with properties {name:exportedKeyword}
				
				if hasKeyword then
					set numFalselyTagged to numFalselyTagged + 1
				end if
				
				set sidecarPath to writeApertureSidecar for currentImage
				
				--set applescript's text item delimiters to "."
				--set fileNameBody to text item -2 of fileName
				
				posixMove of sidecarPath to sidecarDestination
				
				assertFileExists at sidecarDestination given message:"Failed moving sidecar for " & currentImageName & " to its proper destination, " & exportFolderPath
				
				set numSidecarsWritten to numSidecarsWritten + 1
			end if
			tell application "Aperture"
				tell currentImage
					make new keyword with properties {name:exportedKeyword}
				end tell
			end tell
		end if
		set numRemaining to numRemaining - 1
	end repeat
	
	assert against not numRemaining = 0 given message:"Number of exported image sidecars does not add up"
	
on error errStr number errorNumber
	display dialog "An error processing " & currentImageName & " stopped the script with " & numRemaining & " not yet exported. Error: " & errStr
end try

-- post-export warning checks

if numSkippedMovies > 0 then display dialog (numSkippedMovies as string) & " movies included in the selection were skipped and did not get a sidecar"

if numAlreadyExported > 0 then display dialog (numAlreadyExported as string) & " images in selection were skipped since XMP had already been exported. This might not be an error at all, if you have multiple versions for the same master, or willingly selected already exported images."

if numFalselyTagged > 0 then display dialog "Warning: " & (numFalselyTagged as string) & " versions were tagged with " & exportedKeyword & " but had no sidecar. Sidecars have been written for these files, but please check if other image versions may be incorrectly tagged as exported."

if numSkippedMovies + numAlreadyExported + numFalselyTagged = 0 then
	display dialog "Done. " & (numSidecarsWritten as string) & " XMP sidecars successfully written with no errors or warnings."
end if

-- end of main script flow

-- Handlers --

to assert against condition given message:messageStr
	if condition = true then error messageStr
end assert

on checkFileExists at filePath
	--log "checkFileExists " & filePath
	
	set doesExist to false
	try
		do shell script "test ! -f " & quoted form of filePath
	on error errStr number errorNumber
		-- test writes its output to stderr
		if errorNumber = 1 then
			-- 1 = file exists
			set doesExist to true
		else
			-- actual error
			error number errorNumber
		end if
	end try
	--log doesExist
	
	return doesExist
end checkFileExists

to assertFileExists at filePath given message:messageStr
	set fileExists to checkFileExists at filePath
	if not fileExists then error messageStr
end assertFileExists

to getMasterImagePath from imageVersion
	tell application "Aperture"
		set imageid to (id of imageVersion) as string
		set imagename to name of imageVersion as string
	end tell
	
	assert against length of imageid < 4 given message:"Version ID for " & imagename & ": \"" & "\" is conspiciously short"
	
	set dbPath to (apertureLibPath & "/Database/apdb/Library.apdb") as string
	set dbQuery to "select RKVolume.name,imagePath from RKVersion,RKMaster,RKVolume where RKVersion.uuid=" & quoted form of imageid & " AND RKVersion.masterUuid=RKMaster.uuid AND RKVolume.uuid=RKMaster.fileVolumeUuid"
	set dbQuery to "\"" & dbQuery & "\""
	set dbCommandLine to sqlCommand & (quoted form of dbPath) & " " & dbQuery
	
	set dbSuccessful to false
	repeat 10 times
		try
			set dbOutput to do shell script dbCommandLine
			
			set dbSuccessful to true
			exit repeat
		on error errStr number errorNumber
			-- handle DB locked error
			log errorNumber
			log errStr
			if errorNumber = 5 then
				delay 1
			else
				error errStr number errorNumber
			end if
		end try
	end repeat
	
	assert against not dbSuccessful given message:"Could not open connection, Aperture database stays locked across repeated retries."
	
	set AppleScript's text item delimiters to "|"
	
	set diskName to text item 1 of dbOutput
	set masterPath to text item 2 of dbOutput
	set masterImagePath to "/Volumes/" & diskName & "/" & masterPath
	
	assert against length of masterImagePath < 7 given message:"Got invalid path to master image for " & (name of imageVersion)
	
	return masterImagePath
end getMasterImagePath

on writeApertureSidecar for imageVersion
	tell application "Aperture"
		set exportItems to {imageVersion}
		--set exportOutput to (export exportItems using aperturExportImageSetting to (tempExportFolder) metadata sidecar)
		set exportOutput to (export exportItems to tempExportFolder metadata sidecar)
	end tell
	
	set macPath to (item 1 of exportOutput) as string
	set imageExportFile to file macPath as alias
	set imageOutputPath to POSIX path of imageExportFile
	
	-- TODO probably chokes on paths containing dots
	set e to the offset of "." in imageOutputPath
	set sidecarPath to (text 1 thru (e - 1) of imageOutputPath) & "." & apertureSidecarExtension
	assertFileExists at sidecarPath given message:"Can't find written sidecar file for " & imageOutputPath
	
	assertFileExists at imageOutputPath given message:"Can't find written image file at expected place (" & imageOutputPath & ")"
	set deleteCommandLine to "rm " & (quoted form of imageOutputPath)
	do shell script deleteCommandLine
	
	return sidecarPath
	
end writeApertureSidecar

on posixMove of sourceFile to destinationFile
	assert against not item 1 of sourceFile = "/" given message:"posixMove requires absolute paths as arguments; sourceFile is relative"
	assert against length of sourceFile < reasonablePathLength given message:"Move file error: " & sourceFile & " is conspiciously short"
	assert against not item 1 of destinationFile = "/" given message:"posixMove requires absolute paths as arguments; destinationFile is relative"
	assert against length of destinationFile < reasonablePathLength given message:"Move file error: " & destinationFile & " is conspiciously short"
	
	-- -n option prevents overwriting file
	set mvCommandLine to "mv -n " & (quoted form of sourceFile) & " " & (quoted form of destinationFile)
	do shell script mvCommandLine
end posixMove

on checkIfMovie for mediaFileAlias
	--			is in {'mov','m4v',3gp'} then
	
	tell application "Finder"
		set fileType to kind of mediaFileAlias
	end tell
	
	set isMovie to fileType contains "film" -- {"QuickTime-film", "Apple MPEG-4-film", "MPEG-4-film", "3GPP-film"}
	--log fileType & " is movie=" & isMovie
	return isMovie
end checkIfMovie
-- Assign name of selected images' parent album as keyword to all selected images.

tell application "Aperture" to set imageSel to (get selection)

if imageSel is {} then
	error "One image in must be selected within the selected album."
end if

tell application "Aperture"
	set commonAlbum to (parent of item 1 of imageSel)
	set newKeyword to (name of commonAlbum) as string
	
	tell commonAlbum
		set imageList to its every image version
	end tell
end tell

try
	-- Check that all selected images have same parent album
	repeat with i from 1 to count of imageList
		set currentImage to item i of imageList
		tell application "Aperture" to set currentCheckAlbum to parent of currentImage
		assert against not currentCheckAlbum = commonAlbum given message:"All selected images must be part of the same album; some are not."
	end repeat
	
	set currentImage to false
	
	--Set keyword
	repeat with i from 1 to count of imageList
		set currentImage to item i of imageList
		tell application "Aperture"
			tell currentImage
				make new keyword with properties {name:newKeyword}
			end tell
		end tell
	end repeat
	
on error errStr number errorNumber
	display dialog "An error processing " & (name of currentImage as string) & " stopped the script. Error: " & errStr
end try

to assert against condition given message:messageStr
	if condition = true then error messageStr
end assert

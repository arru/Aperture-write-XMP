-- Assign name of selected images' parent album as keyword to all selected images.

tell application "Aperture" to set imageSel to (get selection)

if imageSel is {} then
	error "Please select one or more images."
end if

tell application "Aperture" to set albumName to (name of parent of item 1 of imageSel) as string

try
	-- Check that all selected images have same parent album
	repeat with i from 1 to count of imageSel
		set currentImage to item i of imageSel
		tell application "Aperture" to set currentImageName to name of parent of currentImage as string
		assert against not currentImageName = albumName given message:"All selected images must be part of the same album; some are not."
	end repeat
	
	--Set keyword
	repeat with i from 1 to count of imageSel
		set currentImage to item i of imageSel
		tell application "Aperture"
			tell currentImage
				make new keyword with properties {name:albumName}
			end tell
		end tell
	end repeat
	
on error errStr number errorNumber
	display dialog "An error processing " & (name of currentImage) & " stopped the script. Error: " & errStr
end try

to assert against condition given message:messageStr
	if condition = true then error messageStr
end assert

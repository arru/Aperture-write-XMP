Aperture write XMP script
=========================

### What it does
This script was written for my particular setup, which is:
* Aperture running with a single iPhoto library
* Wanting to migrate to another app, to DarkTable specifically
* Be really stringent about error checking, since I don't want my photo library messed up somehow

Write Aperture XMP makes it an easy routine task to write XMP sidecars for files that have been relocated (i.e. still referenced by Aperture but no longer managed in the Aperture library), without using Aperture's export functionality and thus creating duplicate image masters. The reason you'd want to do this is to keep using both Aperture and the other program you're migrating to (DarkTable in my case) with the same image masters, during a transition/trial period or as long as you like. The tag "DarkTable" is added in Aperture to all images that had their sidecar written successfully.

### What it does not
Due to the way both DarkTable and Aperture handles sidecars, this script _does not provide a sync solution_. Metadata sidecars are written once, and then live their separate lives in Aperture and whatever program you feed the XMP sidecars into. The script also does not quite follow the XMP specification, in that written sidecars are named `imagename.jpg.xmp` while the specification states `imagename.xmp`. This is because DarkTable expects that excentric naming scheme, to make this work with another app that expects `imagename.xmp`, all that needs to be changed in the script is the sidecar destination path. This script also ignores movies by design, but this is really easy to change if you want to use it with movies too.

### What is exported
Aperture XMP export encompasses the following:
* keywords
* rating
* Color labels (see note)
* GPS data, which I believe includes any geotagging done from within Aperture

_Note: Aperture exports color labels by their current name, not the name of the color. If you want them imported into DarkTable, you'll have to remove the text labels associated with the colors (in Preferences) prior to exporting._

### Usage
1. Use the Relocate originals feature in Aperture to put selected images in an external location, which you may choose exactly as you wish
2. Keep the same selection and run this script
3. Import these images into DarkTable

For convenience, you can put the script in `~/Library/Scripts/Applications/Aperture/` and enable the script menu in AppleScript editor's preferences. The script can then be run from the script menu without leaving Aperture.

### Acknowledgements
This script was inspired by several [scripts by Brett Gross](http://brettgrossphotography.com). If you want to customize this script to your own workflow, Brett's script collection will provide recipes and help you overcome numerous AppleScript hurdles

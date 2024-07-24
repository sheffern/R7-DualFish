#!/bin/sh

#  R7DualFishToPanorama.sh
#  SnarkScripts
#
#  Created by Steven Heffern on 7/5/24.
#     Use, steal and edit as needed.
#
# R7DualFishToPanorama photoFile [-k]
#
#  Result is photoFile_Spatial.heic
#
#  You need the spatial command tool from:
#      https://blog.mikeswanson.com/spatial
#  Discussion of the tool from:
#	https://www.youtube.com/watch?v=BHtKOxGEiAw
#
# Also uses Topaz in command line.  Comment that section out if you
# don't want to use it.  I like cleaning up the very small images that
# come from
#
# Updates:
# 	7/22/2024 reversed left and right in the sbs because Hugh Hou says that
#				Canon lense reverses them at capture time, and he is right
#	7/24/2024 changed the -r flag (remove intermediate files) to -k
#				(keep intermediate files)
#				also added test to make sure the input file exists

#
if [ "$1" == "" ]
then
	echo "You need to specify at least one file to convert"
	echo " "
	echo "R7DualFishToPanorama JPGfile [-k]"
	echo " "
	echo "-k will keep the intermediate files"
	
	exit -1
fi

if [ ! -e "$1" ]
then
	echo "File does not exist: $1"
	exit -2
fi


# R7 files are 6960 x 4840
# 1/2 would be 3480 x 4480
# fisheyes are 3200x3200 top is at 640
# The distance between the cwnter of the lenses is 50mm
# The field of view is 144 degrees


filename=$(basename $1)
fname="${filename%.*}"


echo "Working on ${fname}"

right="${fname}_rectright.jpg"
rectfile="${fname}_rectrightb.jpg"
panofile="${fname}_panoleft.jpg"

left="${fname}_rectleft.jpg"
leftrectfile="${fname}_rectleftb.jpg"
leftpanofile="${fname}_panoright.jpg"

sbsfile="${fname}_sbs.jpg"


movie="${fname}_movie.mp4"
anaglyphMovie="${fname}_anaglyphMovie.mp4"
anaglyph="${fname}_Anaglyph.jpg"


# First crop the image into left and right sides

if [ -e "$right" ]
then
rm "$right"
fi
if [ -e "$left" ]
then
rm "$left"
fi

# why is the y different???  was 900 on the right

echo "CROPPING"
ffmpeg -i "$1" -vf  "crop=3200:3200:3646:750" "$right" 2> "${right}.log"
ffmpeg -i "$1" -vf  "crop=3200:3200:50:750" "$left" 2> "${left}.log"


# Then defish the image

if [ -e "$rectfile" ]
then
rm "$rectfile"
fi
if [ -e "$leftrectfile" ]
then
rm "$leftrectfile"
fi

echo "DEFISH"

# This SHOULD work but we still end up being angled
#ffmpeg  -hwaccel auto -i "$right"  -vf "v360=fisheye:e:iv_fov=144,crop=3200:3200,scale=3200:3200,unsharp=5:5:2;" -r 30 "$rectfile"
ffmpeg  -hwaccel auto -i "$right"  -vf "v360=fisheye:e:iv_fov=180,crop=3200:3200,scale=3200:3200,unsharp=5:5:2;" -r 30 "$rectfile" 2> "${rectfile}.log"
ffmpeg  -hwaccel auto -i "$left"  -vf "v360=fisheye:e:iv_fov=180,crop=3200:3200,scale=3200:3200,unsharp=5:5:2;" -r 30 "$leftrectfile" 2> "${leftrectfile}.log"

# Then grab the panorama part of the center of the image

if [ -e "$panofile" ]
then
rm "$panofile"
fi
if [ -e "$leftpanofile" ]
then
rm "$leftpanofile"
fi

echo "CROP DEFISHED"

ffmpeg -i "$rectfile" -vf  "crop=3000:1200:100:800" "$panofile"  2> "${panofile}.log"
ffmpeg -i "$leftrectfile" -vf  "crop=3000:1200:100:800" "$leftpanofile"  2> "${leftpanofile}.log"

echo "Gen Side by Side"
if [ -e "$sbsfile" ]
then
rm "$sbsfile"
fi

# Hugh Hou says that right is left and left is right, and as usual he is right

# ffmpeg -i "$leftpanofile" -i "$panofile" -filter_complex hstack "$sbsfile" 2> "${sbsfile}.log"

ffmpeg  -i "$panofile" -i "$leftpanofile" -filter_complex hstack "$sbsfile" 2> "${sbsfile}.log"



echo "Send this file through Topaz Photo to blow it up cleanly\n Then run spatialfy"

echo "Doing the Topaz now"

backHome="$PWD"
sbssource="$PWD/$sbsfile"
sbstarget="${fname}_sbs-1.jpg"
if [ -e "$sbstarget" ]
then
rm "$sbstarget"
fi

echo "$sbssource"
cd /Applications/Topaz\ Photo\ AI.app/Contents/MacOS
./Topaz\ Photo\ AI --cli "$sbssource"
cd "$backHome"



spatial="${fname}_Spatial.heic"
echo "Using spatial to create a 3d version of this panorama for VisionPro"

spatial make -i "$sbstarget" -o "$spatial" -f sbs --cdist 500 --hfov 144 --hadjust 0  -y

# Okay so now make the anaglyph
# Remove any results and intermediate files

if [ -e "$movie" ]
then
rm "$movie"
fi
if [ -e "$anaglyphMovie" ]
then
rm "$anaglyphMovie"
fi
if [ -e "$anaglyph" ]
then
rm "$anaglyph"
fi

echo "Turning JPG into a 1  second movie"
ffmpeg -loop 1 -framerate 24 -i "$sbstarget" -c:v libx264 -preset slow -tune stillimage -crf 24 -vf format=yuv420p -t 1 -movflags +faststart "$movie" 2> "${fname}_movie.log"

echo "Using ffmpeg stereo to create an anaglyph movie"

ffmpeg -i "$movie"  -vf stereo3d=sbsl:arch "$anaglyphMovie" 2> "${fname}_stereo.log"

# the resulting file colors are totally messed up.  So use Anaglyph Workshop instead

echo "Grabbing the 1st frame to use as our result"

ffmpeg -i "$anaglyphMovie" -ss 00:00:00.001 -f image2 -frames:v 1 "$anaglyph" 2> "${fname}_still.log"





if [ "$2" != "-k" ]
then
echo "Removing log and intermediate files."
rm *.log
rm "$right"
rm "$left"
rm "$panofile"  # leave the one eye pano file
rm "$leftpanofile"  # leave both so we can make an anaglyph using Anaglyph Workshop
rm "$rectfile"
rm "$leftrectfile"
rm "$sbstarget"
rm "$anaglyphMovie"
rm "$movie"
fi

exit 0


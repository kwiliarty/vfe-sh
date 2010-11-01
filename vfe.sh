#!/bin/bash
# video processing script
# syntax vfe.sh [-options] invideo.ext [outvideo]
# version 1.3 
#  -- -l option to set langauge (eng is default)
#  -- -m option to create a corresponding VP8 (.webm) file

# handling for calls without arguments
NO_ARGS=0;
E_OPTERROR=85;

if [ $# -eq "$NO_ARGS" ] #script called without args?
then  
	# explain usage and exit
	echo " "
	echo "  Usage: `basename $0` [-options] infile [outname]"
	echo "  -w : width (in pixels); odd values will be reduced by one"
	echo "  -h : height (in pixels); odd values will be reduced by one"
	echo "  -b : videobitrate (in kb/s)"
	echo "  -f : framerate (per second)"
	echo "  -p : poster frame (in seconds or hh:mm:ss)"
	echo "  -q : create poster.mp4 for quicktime embeds"
	echo "  -c : copy input file as basis for output .mp4. Faster than"
	echo "       transcoding if specs are right. qtfaststart.py will still run."
	echo "  -l : set langauge using ISO 639 3-letter code (e.g., eng)"
	echo "  -m : create a corresponding VP8 (.webm) file"
	echo " "
	exit $E_OPTERROR
fi

# defaults 
width=750
height=420
videobitrate=1500
framerate=30
poster=0
language="eng"

# process options for width and height
while getopts ":w:h:b:f:p:qc:lm" Option
do
	case $Option in
		w ) width=${OPTARG};;
		h ) height=${OPTARG};;
		b ) videobitrate=${OPTARG};;
		f ) framerate=${OPTARG};;
		p ) poster=${OPTARG};;
		q ) postermp4=1;;
		c ) copy=1;;
		l ) language=${OPTARG};;
		m ) webm=1;;
		* ) echo " ";
		    echo "  Unimplemented option chosen.";
		    echo "  Enter the command without options for usage guide.";
			echo " ";
			exit $E_OPTERROR;;
	esac
done

shift $(($OPTIND - 1))

# subtract 1 from odd dimensions
width=$(( ${width} - $(( ${width} % 2 )) ))
height=$(( ${height} - $(( ${height} % 2 )) ))

size="${width}x${height}"

# get the base part of the file name
original=$1
basename=`basename ${original%.*}`

# set the output name
if [ $2 ] #if output name was provided in the command
then 
	outname=$2 #use that output name
else
	outname=$basename #use the basename of the input file
fi

# create a timestamp to use in the folder name
timestamp=$(date "+%Y%m%d%H%M")

# create a unique directory
foldername=${outname}-${timestamp}
mkdir ${foldername}

# process the ogg/theora video
ffmpeg2theora ${original} -o ${foldername}/${outname}.ogv \
 --framerate ${framerate} \
 --width ${width} \
 --height ${height} \
 --keyint 15 \
 --videobitrate ${videobitrate} \
 --soft-target

# copy or transcode the mp4 video
if [ ${copy} ] #if the -c flag was set
then #copy the original file into the destination folder as a -ss.mp4
	  #qtfaststart.py will still operate on this file
	cp ${original} ${foldername}/${outname}-ss.mp4
else #if the -c flag was not set, transcode with ffmpeg
	ffmpeg -i ${original} -s ${size} -b ${videobitrate}k -r ${framerate} -vcodec libx264 -vpre ultrafast -vlang ${language} -alang ${language} -ar 44100 ${foldername}/${outname}-ss.mp4
fi

# create a VP8 (.webm) file
if [ ${webm} ] #if the -m flag was set
then #transcode to .wegm
	ffmpeg -i ${original} -s ${size} -b ${videobitrate}k -r ${framerate} -f webm -vlang ${language} -alang ${language} ${foldername}/${outname}.webm
fi

# create the quickstart version of the mp4 video
qtfaststart.py ${foldername}/${outname}-ss.mp4 ${foldername}/${outname}.mp4

# delete the slow start version
rm ${foldername}/${outname}-ss.mp4

# create the .png poster
ffmpeg -i ${foldername}/${outname}.mp4 -r 1 -t 1 -ss ${poster} \
 -f image2 ${foldername}/${outname}.png

# if the -q flag is set, create the poster.mp4 
if [ ${postermp4} ]
then 
	ffmpeg -i ${foldername}/${outname}.png ${foldername}/${outname}-poster.mp4
fi

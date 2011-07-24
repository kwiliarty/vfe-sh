#!/bin/bash
# video processing script
# syntax vfe.sh [-options] invideo.ext [outvideo]
# version 1.7.1 
#  -- tweaks to webm encode command to better reflect actual options. encode will be slower but file size will be smaller. Many of the usual arguments seem to be ignored by the ffmpeg webm encode, in particular the audio and video data rates.

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
	echo "  -z : set output audio sampling rate (in Hz)"
	echo "  -t : select a libx264 preset"
	echo "  -v : use -vpre instead of -preset (for older versions of ffmpeg)"
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
audiorate=44100
postersource="mp4" #not controlled by a flag but depends on webm availability
ffpreset="ultrafast"
presetflag="-preset" #for newer versions of ffmpeg

# process options for width and height
while getopts ":w:h:b:f:p:qcl:mz:t:v" Option
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
		z ) audiorate=${OPTARG};;
		t ) ffpreset=${OPTARG};;
		v ) presetflag="-vpre";;
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

# prepare some options strings for the transcoding commands
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
 --samplerate ${audiorate} \
 --soft-target

# copy or transcode the mp4 video
if [ ${copy} ] #if the -c flag was set
then #copy the original file into the destination folder as a -ss.mp4
	  #qtfaststart.py will still operate on this file
	cp ${original} ${foldername}/${outname}-ss.mp4
else #if the -c flag was not set, transcode with ffmpeg
	ffmpeg -i ${original} -s ${size} -b ${videobitrate}k -r ${framerate} -vcodec libx264 ${presetflag} ${ffpreset} -vlang ${language} -alang ${language} -ar ${audiorate} ${foldername}/${outname}-ss.mp4
fi

# create a VP8 (.webm) file
if [ ${webm} ] #if the -m flag was set
then #transcode to .webm (and use this file as the poster source)
	ffmpeg -i ${original} -s ${size} -f webm -vcodec libvpx -acodec libvorbis -vlang ${language} -alang ${language} -aq 5 -quality best ${foldername}/${outname}.webm
	postersource="webm"
fi

# create the quickstart version of the mp4 video
qtfaststart.py ${foldername}/${outname}-ss.mp4 ${foldername}/${outname}.mp4

# delete the slow start version
rm ${foldername}/${outname}-ss.mp4

# create the .png poster
ffmpeg -i ${foldername}/${outname}.${postersource} -r 1 -t 1 -ss ${poster} \
 -f image2 ${foldername}/${outname}.png

# if the -q flag is set, create the poster.mp4 
if [ ${postermp4} ]
then 
	ffmpeg -i ${foldername}/${outname}.png ${foldername}/${outname}-poster.mp4
fi

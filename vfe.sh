#!/bin/bash
# video processing script
# syntax vfe.sh [-options] invideo.ext [outvideo]
# version 1.8
#  -- reads a user preference file at ~/.vferc
#  -- option to set webm encoding quality

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
	echo "  -v : use -vpre (for older) or -preset (for newer) ffmpeg"
	echo "  -y : set webm encode quality to 'best' or 'good'."
	echo "       'best' is slow, but produces high quality at a lower bitrate"
	echo "       (available only for ffmpeg > 6)"
	echo " "
	exit $E_OPTERROR
fi

# default settings
width=750 # in pixels
height=420 # in pixels
videobitrate=1500 # in kb/s
framerate=30 # in fps
poster=0 # in seconds or hh:mm:ss
# postermp4=1 # uncomment intial command to set as a default
# copy=1 # uncomment intial command to set as a default 
language="eng" # ISO 639 3-letter code
webm=1 # uncomment intial command to set as a default 
audiorate=44100 # in Hz
ffpreset="ultrafast" # to see options try: sudo find /usr -iname '*.ffpreset'
presetflag="-preset" # for newer versions of ffmpeg. older versions use -vpre
# webmquality="good" # 'best' or 'good'. 
	# 'best' is slow, high quality, low bitrate
	# use this option only for ffmpeg > 6

# user configuration

configfile=~/'.vferc'
configfile_secured='/tmp/.vferc'

if [ -r ${configfile} ] 
then
	egrep '^[^ ;&\$#`]*$' ${configfile} > ${configfile_secured}
	source ${configfile_secured}
fi

# process options for width and height
while getopts ":w:h:b:f:p:qcl:mz:t:v:y:" Option
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
		y ) webmquality=${OPTARG};;
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

# set default poster source
postersource="mp4"

# prepare for webm encode
if [ ${webmquality} ] 
then webmqualityexpression="-quality ${webmquality} "
fi

# create a VP8 (.webm) file
if [ ${webm} ] #if the -m flag was set
then #transcode to .webm (and use this file as the poster source)
	ffmpeg -i ${original} -s ${size} -f webm -vcodec libvpx -acodec libvorbis -vlang ${language} -alang ${language} -ar ${audiorate} -aq 5 ${webmqualityexpression}${foldername}/${outname}.webm
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

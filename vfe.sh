#!/bin/bash
# video processing script
# syntax vfe.sh [-options] invideo.ext [outvideo]
# version 3.0
# --adjustments to work with ffmpeg 1+
# ----using -b:v instead of -b which ffmpeg 1 considers 'ambiguous'

# handling for calls without arguments
NO_ARGS=0;
E_OPTERROR=85;

if [ $# -eq "$NO_ARGS" ] #script called without args?
then  
	# explain usage and exit
	echo " "
	echo "  Usage: `basename $0` [-options] infile [outname]"
	echo "  -d : choose a converter -- 'ffmpeg' or 'avconv'"
	echo "  -w : width (in pixels); odd values will be reduced by one"
	echo "  -h : height (in pixels); odd values will be reduced by one"
	echo "  -b : videobitrate (in kb/s)"
	echo "  -a : display aspect ratio (w:h)"
	echo "  -f : framerate (per second)"
	echo "  -r : audio bit rate (in kb/s) (64 or 128 recommended)"
	echo "  -p : poster frame (in seconds or hh:mm:ss)"
	echo "  -q : create poster.mp4 for quicktime embeds"
	echo "  -c : copy input file to use as one of the outputs. Faster than"
	echo "       transcoding if specs are right. qtfaststart.py will still run."
	echo "  -l : set langauge using ISO 639 3-letter code (e.g., eng)"
	echo "  -m : create a corresponding VP8 (.webm) file"
	echo "  -z : set output audio sampling rate (in Hz)"
	echo "  -t : select a libx264 preset"
	echo "  -v : use -vpre (for older) or -preset (for newer) ffmpeg"
	echo "  -y : set webm encode quality to 'best' or 'good'."
	echo "       'best' is slow, but produces high quality at a lower bitrate"
	echo "       (available only for ffmpeg > 6)"
	echo "  -e : path to preset file"
	echo " "
	exit $E_OPTERROR
fi

# default settings

converter="ffmpeg"
# ffmpeg or avconv

width=750 
# in pixels

height=420 
# in pixels

videobitrate=1500 
# in kb/s

framerate=30 
# in fps

audiobitrate=128
# in kb/s

poster=0 
# in seconds or hh:mm:ss

# postermp4=1 
# uncomment intial command to set as a default

# copy=1 
# uncomment intial command to set as a default 

language="eng" 
# ISO 639 3-letter code

webm=1 
# uncomment intial command to set as a default 

audiorate=44100 
# in Hz

ffpreset="ultrafast" 
# to see options try: sudo find /usr -iname '*.ffpreset'

presetflag="-preset" 
# for newer versions of ffmpeg. older versions use -vpre

# webmquality="good" 
# 'best' or 'good'. 
	# 'best' is slow, high quality, low bitrate
	# use this option only for ffmpeg > 6
	# leave empty to let the video bitrate prevail

# read user configuration

configfile=~/'.vferc'
configfile_secured='/tmp/.vferc'

if [ -r ${configfile} ] 
then
	egrep '^[^ ;&\$#`]*$' ${configfile} > ${configfile_secured}
	source ${configfile_secured}
fi

# process options for width, height, etc.

while getopts ":d:w:h:b:a:f:r:p:qcl:mz:t:v:y:e:" Option
do
	case $Option in
		d ) converter=${OPTARG};;
		w ) width=${OPTARG};;
		h ) height=${OPTARG};;
		b ) videobitrate=${OPTARG};;
		a ) aspect=${OPTARG};;
		f ) framerate=${OPTARG};;
		r ) audiobitrate=${OPTARG};;
		p ) poster=${OPTARG};;
		q ) postermp4=1;;
		c ) copy=1;;
		l ) language=${OPTARG};;
		m ) webm=1;;
		z ) audiorate=${OPTARG};;
		t ) ffpreset=${OPTARG};;
		v ) presetflag="-vpre";;
		y ) webmquality=${OPTARG};;
		e ) vfepreset=${OPTARG};;
		* ) echo " ";
		    echo "  Unimplemented option chosen.";
		    echo "  Enter the command without options for usage guide.";
			echo " ";
			exit $E_OPTERROR;;
	esac
done

shift $(($OPTIND - 1))

# apply values from a vfe preset file if the -e flag is set and the file exists
if [ ${vfepreset} ] && [ -r "${vfepreset}" ]
then
	tmppreset='/tmp/tmppreset'
	egrep '^[^ ;&\$#`]*$' "${vfepreset}" > ${tmppreset}
	source ${tmppreset}
fi

#### manage some variables, defaults, and validation
#### put strings into appropriate command form

# if converter is not avconv, then it must be ffmpeg
if [ "${converter}" != "avconv" ]
then
	converter="ffmpeg"
fi

# subtract 1 from odd dimensions
width=$(( ${width} - $(( ${width} % 2 )) ))
height=$(( ${height} - $(( ${height} % 2 )) ))

# create size string
size="${width}x${height}"

# create the aspect string
if [ ${aspect} ] # if the -a option was set
then
	aspectstring="-aspect ${aspect} "
else
	aspectstring=""
fi

# create the lang strings
if [ "${converter}" = "avconv" ] # when using avconv
then
	langstring="-metadata:s:a:0 language=${language} "
else
	# for ffmpeg < 1
	# langstring="-vlang ${language} -alang ${language} "
	# for ffmpeg >= 1
	langstring="-metadata:s:a:1 language=${language} "
fi

# parse the file name
original=$1
basename=`basename ${original%.*}`
extension=`basename ${original##*.}`

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

# copy or process the ogg/theora video
if [ ${copy} ] && [ "${extension}" = "ogv" ] #if -c flag set and file ogv
then #copy the original file into the destination folder
	echo "**************************************"
	echo "Copying the original .ogv file"
	echo "**************************************"
	cp ${original} ${foldername}/${outname}.ogv
else #transcode with ffmpeg or avconv
	echo "**************************************"
	echo "Transcoding to .ogv using the command:"
	oggcommand="${converter} -i ${original} -s ${size} ${aspectstring}-b:v ${videobitrate}k -r ${framerate} -ab ${audiobitrate}k -vcodec libtheora ${langstring}-ar ${audiorate} -acodec libvorbis ${foldername}/${outname}.ogv"
	echo "${oggcommand}"
	echo "*************************************"
	${oggcommand}
fi


# copy or transcode the mp4 video
if [ ${copy} ] && [ "${extension}" = "mp4" ] #if the -c flag set and file is mp4
then #copy the original file into the destination folder as a -ss.mp4
	  #qtfaststart.py will still operate on this file
	echo "**************************************"
	echo "Copying the original .mp4 file"
	echo "**************************************"
	cp ${original} ${foldername}/${outname}-ss.mp4
else #if the -c flag was not set, transcode with ffmpeg
	echo "**************************************"
	echo "Trancoding to .mp4 using the command:"
	mpegcommand="${converter} -i ${original} -s ${size} ${aspectstring}-b:v ${videobitrate}k -r ${framerate} -ab ${audiobitrate}k -vcodec libx264 ${presetflag} ${ffpreset} ${langstring}-ar ${audiorate} -strict experimental ${foldername}/${outname}-ss.mp4"
	echo "${mpegcommand}"
	echo "**************************************"
	${mpegcommand}
fi

# set default poster source
postersource="mp4"

# prepare for webm encode
if [ ${webmquality} ] 
then webmqualityexpression="-quality ${webmquality} "
fi

# create or copy a VP8 (.webm) file
if [ ${webm} ] #if the -m flag was set
then #copy or transcode to .webm (and use this file as the poster source)
	if [ ${copy} ] && [ "${extension}" = "webm" ] #if -c flag and .webm file
	then
		echo "**************************************"
		echo "Copying the original .webm file"
		echo "**************************************"
		cp ${original} ${foldername}/${outname}.webm
	else
		echo "**************************************"
		echo "Transcoding to .webm using the command:"
		webmcommand="${converter} -i ${original} -s ${size} ${aspectstring}-f webm -vcodec libvpx -acodec libvorbis ${langstring}-ar ${audiorate} -ab ${audiobitrate}k -aq 5 -vb ${videobitrate}k ${webmqualityexpression}${foldername}/${outname}.webm"
		echo "${webmcommand}"
		echo "**************************************"
		${webmcommand}
	fi
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

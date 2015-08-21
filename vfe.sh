#!/bin/bash
# video processing script
# syntax vfe.sh [-options] invideo.ext [outvideo]
# version 3.2.1
# -- remove a couple hard-coded ffmpeg calls to be converter-agnostic
# -- suppress the webm -quality flag with avconv

# function to examine settings
examine_settings() {

    line="                               "

    postermp4pref="Do not create a poster for QT embed"
    if [ ${postermp4} ]
    then postermp4pref="Create a poster for QT embed"
    fi

    copypref="Do not use the input file as one of the outputs"
    if [ ${copy} ] 
    then copypref="Use the input file as one of the outputs"
    fi

    webmpref="Do not create a webm version"
    if [ ${webm} ]
    then webmpref="Create a webm version"
    fi

    examinepref="Do not show verbose settings information"
    if [ ${examine} -eq 1 ]
    then examinepref="Show verbose settings information"
    fi

    settings="$settings
    $1

      -d : converter=$converter ${line:10+${#converter}} : Use $converter to transcode media
      -w : width=$width ${line:6+${#width}} : Width (in pixels) of output 
      -h : height=$height ${line:7+${#height}} : Height (in pixels) of output
      -a : aspect=$aspect ${line:7+${#aspect}} : Explicit Display Aspect Ration (DAR)
      -b : videobitrate=$videobitrate ${line:13+${#videobitrate}} : Video bitrate (in kb/s)
      -f : framerate=$framerate ${line:10+${#framerate}} : Framerate (per second)
      -r : audiobitrate=$audiobitrate ${line:13+${#audiobitrate}} : Audio bitrate (in kb/s)
      -p : poster=$poster ${line:7+${#poster}} : Designate a poster from (in seconds or hh:mm:ss)
      -q : postermp4=$postermp4 ${line:10+${#postermp4}} : ${postermp4pref}
      -c : copy=$copy ${line:5+${#copy}} : ${copypref}
      -l : language=$language ${line:9+${#language}} : ISO 639 3-letter language code
      -m : webm=$webm ${line:5+${#webm}} : ${webmpref}
      -z : audiorate=$audiorate ${line:10+${#audiorate}} : Audio sampling rate (in Hz)
      -t : ffpreset=$ffpreset ${line:9+${#ffpreset}} : Select a libx264 preset
      -v : presetflag=$presetflag ${line:11+${#presetflag}} : '-preset' (or '-vpre' for older ffmpeg) 
      -y : webmquality=$webmquality ${line:12+${#webmquality}} : 'best' or 'good'
      -e : vfepreset=$vfepreset ${line:10+${#vfepreset}} : Path to preset file for vfe.sh
      -s : faststartcommand=$faststartcommand ${line:17+${#faststartcommand}} : 'qtfaststart', 'qtfaststart.py' or 'qt-faststart'
      -x : examine=$examine ${line:8+${#examine}} : ${examinepref}
    "
}

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

faststartcommand="qtfaststart.py"
# depending on your set-up, the other alternatives are "qtfaststart" and "qt-faststart"

# do not list out settings by default
examine=0;

# record default settings
examine_settings "Default values set by vfe.sh"

# handling for calls without arguments
NO_ARGS=0;
E_OPTERROR=85;

# if [ $# -eq "$NO_ARGS" ] #script called without args?
if [ -z "$1" ] # no file specified
then  
	# explain usage and exit
	echo " "
	echo "  Usage: `basename $0` [-options] infile [outname]"
    echo "$settings";
	exit $E_OPTERROR
fi

# read user configuration

configfile=~/'.vferc'
configfile_secured='/tmp/.vferc'

if [ -r ${configfile} ] 
then
	egrep '^[^ ;&\$#`]*$' ${configfile} > ${configfile_secured}
	source ${configfile_secured}
    # record config file settings
    examine_settings "Values after applying $configfile"
fi

# process options for width, height, etc.

while getopts ":d:w:h:b:a:f:r:p:qcl:mz:t:v:y:e:s:x" Option
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
		v ) presetflag=${OPTARG};;
		y ) webmquality=${OPTARG};;
		e ) vfepreset=${OPTARG};;
		s ) faststartcommand=${OPTARG};;
		x ) examine=1;;
		* ) echo " ";
		    echo "  Unimplemented option chosen.";
		    echo "  Enter the command without options for usage guide.";
			echo " ";
			exit $E_OPTERROR;;
	esac
done

shift $(($OPTIND - 1))

# record command line settings
examine_settings "Values after applying command-line options"

# apply values from a vfe preset file if the -e flag is set and the file exists
if [ ${vfepreset} ] && [ -r "${vfepreset}" ]
then
	tmppreset='/tmp/tmppreset'
	egrep '^[^ ;&\$#`]*$' "${vfepreset}" > ${tmppreset}
	source ${tmppreset}
    # record settings information
    examine_settings "Values after applying the options in $vfepreset"
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

# validate the preset flag
if [ "$presetflag" != "-vpre" ]
then presetflag="-preset"
fi

# validate the webm quality
if [ "$webmquality" != "best" ]
then webmquality="good"
fi

# validate the faststart command
if [ "$faststartcommand" != "qtfaststart.py" -a "$faststartcommand" != "qt-faststart" ]
then faststartcommand="qtfaststart"
fi

# one last pass at the settings
examine_settings "Values after a bit of validation"

# Display settings information
if [ ${examine} -eq 1 ]
then
    echo "$settings"
fi

# exit if no file specified
if [ -z $1 ]
then
    exit $E_OPTERROR;
fi

#### create some additional strings
# create size string
size="${width}x${height}"

# create the aspect string
if [ ${aspect} ] # if the -a option was set
then
	aspectstring="-aspect ${aspect} "
else
	aspectstring=""
fi

# create the lang string
langstring="-metadata:s language=${language} "

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
	oggcommand="${converter} -i ${original} -s ${size} ${aspectstring}-b:v ${videobitrate}k -r ${framerate} -b:a ${audiobitrate}k -c:v libtheora ${langstring}-ar ${audiorate} -c:a libvorbis ${foldername}/${outname}.ogv"
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
	mpegcommand="${converter} -i ${original} -s ${size} ${aspectstring}-b:v ${videobitrate}k -r ${framerate} -b:a ${audiobitrate}k -c:v libx264 -c:a aac ${presetflag} ${ffpreset} ${langstring}-ar ${audiorate} -strict experimental ${foldername}/${outname}-ss.mp4"
	echo "${mpegcommand}"
	echo "**************************************"
	${mpegcommand}
fi

# set default poster source
postersource="mp4"

# prepare for webm encode
if [ ${converter} == 'ffmpeg' ] 
then webmqualityexpression="-quality ${webmquality} "
else webmqualityexpression=''
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
		webmcommand="${converter} -i ${original} -s ${size} ${aspectstring}-f webm -c:v libvpx -c:a libvorbis ${langstring}-ar ${audiorate} -b:a ${audiobitrate}k -aq 5 -vb ${videobitrate}k ${webmqualityexpression}${foldername}/${outname}.webm"
		echo "${webmcommand}"
		echo "**************************************"
		${webmcommand}
	fi
	postersource="webm"
fi

# create the quickstart version of the mp4 video
${faststartcommand} ${foldername}/${outname}-ss.mp4 ${foldername}/${outname}.mp4

# delete the slow start version
rm ${foldername}/${outname}-ss.mp4

# create the .png poster
${converter} -i ${foldername}/${outname}.${postersource} -r 1 -t 1 -ss ${poster} \
 -f image2 ${foldername}/${outname}.png

# if the -q flag is set, create the poster.mp4 
if [ ${postermp4} ]
then 
	${converter} -i ${foldername}/${outname}.png ${foldername}/${outname}-poster.mp4
fi

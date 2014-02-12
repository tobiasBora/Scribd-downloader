#!/bin/bash -e
# This script created by Tobias Bora is under GPLv3 Licence

# This script download and convert a document from scribd.com into pdf
# ImageMagick and Phantomjs must be installed
# Doc : https://github.com/ariya/phantomjs/wiki/API-Reference-WebPage#wiki-webpage-viewportSize

# Working examples :
# http://fr.scribd.com/doc/16920981/Secondhand-Serenade-Your-Call-piano"
# http://fr.scribd.com/doc/24816204/Vanessa-Carlton-A-Thousand-Miles
# Example of forbidden file at the beginning that this script can
# find and convert :
# http://fr.scribd.com/doc/48491291/partition

# If you don't want install phantomjs/imagemagick,
# you can just put phantomjs and convert exec files
# is in the current directory

if [ -z "$1" ]
then
    echo "scribd_download.sh <url>"
    echo "or if you want to change the number of pages :"
    echo "scribd_download.sh <url> <number of pages>"
    echo "or if you want to specify the width/height manually :"
    echo "scribd_download.sh <url> <number of pages> <width> <height>"
    echo "If you don't want to specify the number of pages :"
    echo "scribd_download.sh <url> 0 <width> <height>"
    exit 1
fi

# If convert isn't installed
if [ -z "$(which convert)" ]
then
    file="$(dirname $(readlink -f .))/convert"
    # Even in the current dir
    if [ ! -f "$file" ]
    then
	echo "You must install 'convert' from the package imagemagick."
	echo "On ubuntu run :"
	echo "sudo apt-get install imagemagick"
	exit 1
    else
	echo "The convert command has been found in the current dir."
	echo "I'll use it."
	exec_convert="$file"
    fi
else
    exec_convert="convert"
fi

# If phantomjs isn't installed
if [ -z "$(which phantomjs)" ]
then
    file="$(dirname $(readlink -f .))/phantomjs"
    # Even in the current dir
    if [ ! -f "$file" ]
    then
	echo "You must install phantomjs."
	echo "On ubuntu run :"
	echo "sudo apt-get install phantomjs"
	exit 1
    else
	echo "The phantomjs command has been found in the current dir."
	echo "I'll use it."
	exec_phantomjs="$file"
    fi
else
    exec_phantomjs="phantomjs"
fi



url="$1"
zoom_precision=2

rm -rf .tmp
mkdir .tmp
cd .tmp

# Get the number of pages
echo "Getting informations..."
echo "(It can be quite long, and don't worry if"
echo "you see some errors during the conversion)"
echo -n "  Number of pages... "

echo "var page = require('webpage').create();
url = \"$url\"
page.open(url, function () {
    console.log(page.content);
    phantom.exit();
});
// Avoid error messages
page.onError = function(msg, trace) {
};
" > phantom_nb_pages.js

# Update of Scribd
$exec_phantomjs --load-images=no phantom_nb_pages.js > page.html
nb_pages="$(cat page.html | grep 'document.getElementById(\"outer_page' | wc -l)"

if [ -z "$2" ] || [ "$2" = "0" ]
then
    if [ -z "$nb_pages" ]
    then
	echo "I can't find the number of pages... Please, how many pages are there in the file ?"
	read nb_pages
    fi
else
    nb_pages="$2"
fi
echo "$nb_pages"

page_name=`cat page.html | egrep -o "<title>.*</title>" | sed -E 's/<title>(.*)<\/title>/\1/' | sed -e 's/ /_/g'`
echo "  Title... $page_name"
echo "Done."

# We remove useless parts in files
echo "Removing useless parts..."

# We make a new line for each html element.
sed -i -e "s/</\\n</g" page.html
sed -i -e "s/>[^\\n]/>\\n/g" page.html

function remove_node {
    # $1 is the node regexp string
    # $2 is the file
    node_regex=$1
    filename=$2
    commande="{if(!i && /${node_regex}/){i=1}else{if(i){if(/<div/){i++} if(/<\/div>/){i--}}else{if(!i){print \$0}} }}"
    awk "$commande" "$filename" > tmp
    mv tmp "$filename"
    
}

function remove_n_node {
    # $1 is the node regexp string
    # $2 is the file
    node_regex=$1
    filename=$2
    n=$3
    commande="BEGIN {l=${n}} {if( !i && l>0 && /${node_regex}/ ){i=1;l--}else{if(i){if(/<div/){i++} if(/<\/div>/){i--}}else{if(!i){print \$0}} }}"
    awk "$commande" "$filename" > tmp
    mv tmp "$filename"
    
}

function keep_n_node {
    # $1 is the node regexp string
    # $2 is the file
    node_regex=$1
    filename=$2
    n=$3
    commande="BEGIN {l=${n}} {if(l > 0 && /${node_regex}/ ){l--;print \$0}else{if(!i && /${node_regex}/ ){i=1;l--}else{if(i){if(/<div/){i++} if(/<\/div>/){i--}}else{if(!i){print \$0}} }}}"
    awk "$commande" "$filename" > tmp
    mv tmp "$filename"
    
}

function remove_errors {
    awk '/</{i++}i' "$1" > tmp
    mv tmp "$1"
}


# We remove the margin on the left of the main block
sed -i -e 's/id="doc_container"/id="doc_container" style="min-width:0px;margin-left : 0px;"/g' page.html


# We remove all html elements which are useless (menus...)
echo -n "-"
remove_errors "page.html"
echo -n "-"
remove_node '<div.*id="global_header"' "page.html"
echo -n "-"
remove_node '<div class="header_spacer"' "page.html"
echo -n "-"
remove_node '<div.*id="doc_info"' "page.html"
echo -n "-"
remove_node '<div.*class="toolbar_spacer"' "page.html"
echo -n "-"
remove_node '<div.*between_page_ads_1' "page.html"
echo -n "-"
remove_node 'id="leaderboard_ad_main">' "page.html"
echo -n "-"
# Remove the space between pages
remove_node 'class="page_missing_explanation ' "page.html"
echo -n "-"
remove_node '<div id="between_page_ads' "page.html"
echo -n "-"
remove_node '<div class="b_..">' "page.html"
echo -n "-"
remove_node '<div class="buy_doc_bar' "page.html"

sed -i 's/<div class="outer_page/<div style="margin: 0px;" class="outer_page/g' page.html

# Remove shadow on forbidden pages
echo -n "-"
remove_node '<div class="shadow_overlay">' "page.html"
echo -n "-"
remove_node 'grab_blur_promo_here' "page.html"
echo -n "-"
remove_node 'missing_page_buy_button' "page.html"

echo -e "\nDone"


# We download the page with images
echo "Downloading page..."

# Automatic detection
if [ -z "$4" ]
then
    #### The page size is founded automatiquely
    # New way : with this way it should be possible to
    # choose the size of each page
    width_no_zoom="$(cat page.html  | grep -o '\"origWidth\": [0-9]*' | head -n 1 | awk -F ' ' '{print $2}')"
    height_no_zoom="$(cat page.html  | grep -o '\"origHeight\": [0-9]*' | head -n 1 | awk -F ' ' '{print $2}')"

    # If it doesn't work
    if [ -z "$width_no_zoom" ]
    then
	echo "The first detection didn't work..."
	width_no_zoom="$(cat page.html | grep 'id=\"outer_page_1' | egrep -o '[0-9]+px' | egrep -o '[0-9]+' | awk 'NR == 1')"
	height_no_zoom="$(cat page.html | grep 'id=\"outer_page_1' | egrep -o '[0-9]+px' | egrep -o '[0-9]+' | awk 'NR == 2')"
    else
	echo "Detection successfull !"
	# If it works we modify the Javascript to have the good width
	sed -i "s/var defaultViewWidth .*;/var defaultViewWidth = defaultViewWidth || $width_no_zoom;/g" page.html
    fi
else
    width_no_zoom="$3"
    height_no_zoom="$4"
fi
# space_no_zoom=100
space_no_zoom=0
echo "Width : $width_no_zoom px"
echo "Height : $height_no_zoom px"
echo "If you have an error here, make sure phantomjs is installed."

width=$(($width_no_zoom * $zoom_precision))
height=$(($height_no_zoom * $zoom_precision))
space=$(($space_no_zoom * $zoom_precision))

# We treat each pages 10 by 10 because phantomjs can't manage to deal
# with big documents (something like 20 pages)

current_page=0
leaving_pages="$nb_pages"
max_treat=10

# We make a copy in order to remove useless pages
# page_svg.html contains all pages which hasn't been recorded
cp page.html page_svg.html

# We treat pages until all pages are treated
while [ "$leaving_pages" -gt "0" ]
do
    if [ "$leaving_pages" -lt "$max_treat" ]
    then
	nb_pages_to_treat="$leaving_pages"
	leaving_pages=0
    else
	nb_pages_to_treat="$max_treat"
	leaving_pages="$(($leaving_pages - $max_treat))"
    fi

    echo "Treating $nb_pages_to_treat pages ($leaving_pages leaving pages after that, $current_page already downloaded)"
    cp page_svg.html page.html
    keep_n_node 'id="outer_page_' "page.html" "$nb_pages_to_treat"
    
    echo "var page = require('webpage').create();
output='out.png';
address = 'page.html';
nb_pages = $nb_pages_to_treat;
zoom = $zoom_precision;
width = $width
height = (768+($height+$space)*nb_pages);
page.viewportSize = { width: width, height: height };
page.zoomFactor = zoom;
page.open(address, function (status) {
    if (status !== 'success') {
        console.log('Unable to load the address!');
    } else {
        page.clipRect = { top: 0, left: 0, width: width, height: height };
        window.setTimeout(function () {
            page.render(output);
            phantom.exit();
        }, 200);
    }
});
// Avoid error messages
page.onError = function(msg, trace) {
};
" > phantom_render.js
    
    $exec_phantomjs phantom_render.js
    
    echo "Done"
    
     ### Treatment of the picture
    # Separate pages
    echo "Treatment... "
    
    for i in `seq 0 $(( $nb_pages_to_treat - 1))`
    do
        # We add zeros to fill the page number in file name
	printf -v page_filename "%05d.png" "$current_page"
        # We select the good page and save it in a new file
	$exec_convert out.png -gravity NorthWest -crop ${width}x${height}+0+$(( $i*($height + $space) )) $page_filename
	current_page="$(($current_page + 1))"
    done

    ### Remove useless pages in page.html
    if [ "$leaving_pages" -ne "0" ]
    then
	remove_n_node 'id="outer_page_' "page_svg.html" "$nb_pages_to_treat"
    fi
done

# Create the pdf file
echo "All pages have been downloaded, I will now create the pdf file"
$exec_convert 0*.png -quality 100 -compress jpeg -gravity center -resize 1240x1753 -extent 1240x1753 -gravity SouthWest -page a4 ../${page_name}.pdf

echo "Done"
echo "The outputfile is ${page_name}.pdf"

cd ..
rm -rf .tmp

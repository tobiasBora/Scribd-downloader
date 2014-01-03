#!/bin/bash -e

# This script download and convert a document from scribd.com into pdf
# ImageMagick and Phantomjs must be installed
# Doc : https://github.com/ariya/phantomjs/wiki/API-Reference-WebPage#wiki-webpage-viewportSize

# Working examples :
# http://fr.scribd.com/doc/16920981/Secondhand-Serenade-Your-Call-piano"
# http://fr.scribd.com/doc/24816204/Vanessa-Carlton-A-Thousand-Miles


# Bugs: Letters are missing in this page :
# url="http://fr.scribd.com/doc/48491291/partition"

if [ -z "$1" ]
then
    echo "scribd_download.sh <url>"
    exit 1
fi
url="$1"
zoom_precision=2

rm -rf .tmp
mkdir .tmp
cd .tmp

# Get the number of pages
echo "Getting informations..."
echo -n "  Number of pages... "

echo "var page = require('webpage').create();
url = \"$url\"
page.open(url, function () {
    console.log(page.content);
    phantom.exit();
});" > phantom_nb_pages.js

# Update of Scribd
nb_pages=`phantomjs --load-images=no phantom_nb_pages.js > page.html && cat page.html | egrep -o 'of <span class="total_value">[0-9]+</span>' | cut -d\> -f2 | cut -d\< -f1`
if [ -z "$nb_pages" ]
then
    echo "I can't find the number of pages... Please, how many pages are there in the file ?"
    read nb_pages
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
    commande="{if(/${node_regex}/){i=1}else{if(i){if(/<div/){i++} if(/<\/div>/){i--}}else{if(!i){print \$0}} }}"
    awk "$commande" "$filename" > tmp
    mv tmp "$filename"
    
}

function remove_errors {
    awk '/</{i++}i' "$1" > tmp
    mv tmp "$1"
}

# We remove the margin on the left of the main block
sed -i -e 's/id="doc_container"/id="doc_container" style="margin-left : 0px;"/g' page.html

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

# The Scribt skeleton changes often, the following things are useless now.
# echo -n "-"
# remove_node '<div class="global_header"' "page.html"
# echo -n "-"
# remove_node '<div id="font_preload_bed"' "page.html"
# echo -n "-"
# remove_node '<div class="global_footer"' "page.html"
# echo -n "-"
# remove_node '<div id="lightboxes"' "page.html"
# echo -n "-"
# remove_node '<div id="fb-root"' "page.html"
# echo -n "-"
# remove_node '<div id="overlay"' "page.html"
# echo -n "-"
# remove_node '<div class="below_document"' "page.html"
# echo -n "-"
# remove_node 'id="top_language_bar">' "page.html"
# echo -n "-"
# remove_node '<div id="upgrade_message"' "page.html"
# echo -n "-"
# remove_node 'id="flashes_placeholder"' "page.html"
# echo -n "-"
# remove_node 'class="sticky_bar"' "page.html"
# echo -n "-"
# remove_node 'id="sidebar"' "page.html"
# echo -n "-"
# remove_node 'id="view=mode_popup"' "page.html"
# echo -n "-"
# remove_node '<div class="b_' "page.html"

echo -e "\nDone"


# We download the page with images
echo "Downloading page..."

#### The page size is founded automatiquely
width_no_zoom="$(cat page.html | grep 'id=\"outer_page_1' | egrep -o '[0-9]+px' | egrep -o '[0-9]+' | awk 'NR == 1')"
height_no_zoom="$(cat page.html | grep 'id=\"outer_page_1' | egrep -o '[0-9]+px' | egrep -o '[0-9]+' | awk 'NR == 2')"
space_no_zoom=100

echo "Width : $width_no_zoom px"
echo "Height : $height_no_zoom px"
echo "If you have an error here, if may have a problem to detect the width."

width=$(($width_no_zoom * $zoom_precision))
height=$(($height_no_zoom * $zoom_precision))
space=$(($space_no_zoom * $zoom_precision))

echo "var page = require('webpage').create();
url = 'page.html';
nb_pages = $nb_pages;
zoom = $zoom_precision;
width = $width
height = (768+($height+$space)*nb_pages);
page.viewportSize = { width: width, height: height };
page.zoomFactor = zoom;

page.open(url, function () {
    page.render('out.png');
    phantom.exit();
    
});
" > phantom_render.js

phantomjs phantom_render.js

echo "Done"

### Treatment of the picture
# Separate pages
echo -n "Treatment... "

for i in `seq 0 $(( $nb_pages - 1))`
do
    # We add zeros to fill the page number in file name
    printf -v page_filename "%05d.png" $i
    # We select the good page and save it in a new file
    convert out.png -gravity NorthWest -crop ${width}x${height}+0+$(( $i*($height + $space) )) $page_filename
done

# Create the pdf file
convert 0*.png -quality 100 -compress jpeg -gravity center -resize 1240x1753 -extent 1240x1753 -gravity SouthWest -page a4 ../${page_name}.pdf

echo "Done"
echo "The outputfile is ${page_name}.pdf"

cd ..
rm -rf .tmp



###### Bin #####
# This part must be improve because it is very long... DONE !
# function remove_node {
#      # $1 is the node regexp string
#      # $2 is the file
#     node_regex=$1
#     filename=$2
#     state=0
#     nb_line=1
#     while read line
#     do
#  	if [ $state = 0 ]
#  	then
#  	    # On n'a encore rien trouvé
#  	    if [ "`echo \"$line\" | grep -o -P \"$node_regex\"`" != "" ]
#  	    then
#  		sed -i "${nb_line}d" $filename
#  		nb_line=$(( $nb_line - 1 ))
#  		state=1
#  		i=1
#  	    fi
#  	elif [ $state = 1 ]
#  	then
#  	    # On est dans la partie à supprimer
#  	    sed -i "${nb_line}d" "$filename"
#  	    # On évite de sauter des lignes
#  	    nb_line=$(( $nb_line - 1 ))	    
#  	    if [ "`echo \"$line\" | grep -o '</div>'`" != "" ]
#  	    then
#  		i=$(( $i - 1 ))
#  	    elif [ "`echo \"$line\" | grep -o '<div'`" != "" ]
#  	    then
#  		i=$(( $i + 1 ))
#  	    fi

#  	    if [ $i == 0 ]
#  	    then
#  		state=0
#  	    fi
#  	fi
#  	nb_line=$(( $nb_line + 1 ))
#     done < $filename
# }

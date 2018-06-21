if [ "$#" -lt "5" ]; then
    echo "Please specify the ABSOLUTE paths to the Git Repository and RTC Workspace parent directory"
    echo "followed by Workspace name, Component name, Stream name and optional date preservation flag!"
    echo 
    exit
fi

# $1 = Git Repository
# $2 = RTC Workspace parent directory
# $3 = Workspace name
# $4 = Component name
# $5 = Stream name
# $6 = Date preservation flag

echo "Git Repository                  : $1"
echo "RTC Workspace parent directory  : $2"
echo "Workspace name                  : $3"
echo "Component name                  : $4"
echo "Stream name                     : $5"
echo "Date preservation flag          : `expr "$6" != ""`"

pushd $1 > /dev/null
IFS=$'\r\n' GLOBIGNORE='*' command eval  'array=($(git log --pretty=format:%H))'
echo "Total commits in Git Repository is ${#array[@]}"
popd > /dev/null
read -n 1 -p "Please verify the above and press any key to proceed or Ctrl-C to abort..."

shopt -s dotglob
echo "Initializing RTC Workspace..."
lscm create workspace -r local -s $5 $3
lscm create component -r local $4 $3
mkdir $2/$3 > /dev/null
pushd $2/$3 > /dev/null
lscm load -d $2/$3 -i $3 $4 -r local
#cp $2/jazzfile/.jazzignore $2/$3/$4
#lscm checkin -n -d $2/$3 .
#lscm deliver
popd > /dev/null

if [ ! -z "$6" ]; then 
    saved_date="$(date)"
fi

echo "Begin exporting Git to RTC..."
pushd $1 > /dev/null
for (( i=${#array[@]}-1;i>=0;i-- )); do
    chash="${array[i]}"
    echo "Checking out $chash..."
    git reset --hard $chash
    ctag="$(git tag --points-at $chash)"
    cmessage="$(git log -n 1 --pretty=format:%s $chash)"
    cdate="$(git show -s --format=%cd --date=local $chash)"

    echo "Commit hash    : $chash"
    echo "Commit date    : $cdate"
    echo "Tag name       : $ctag"
    echo "Commit message : $cmessage"

    if [ ! -z "$6" ]; then
        date -s "$cdate"
    fi

    cp -rv $1/* $2/$3/$4 > /dev/null
    rm -rf $2/$3/$4/.git > /dev/null
    pushd $2/$3 > /dev/null
    lscm checkin -n -d $2/$3 --comment "`echo $cmessage$'\n\n'Hash: $chash$'\n'Date: $cdate$'\n'Tag: $ctag`" --complete $2/$3

    if [ ! -z "$ctag" ]; then
        lscm create baseline -r local $3 $ctag $4
    fi

    lscm deliver
    rm -rf $4/*
    popd > /dev/null
done

if [ ! -z "$6" ]; then
    date -s "$saved_date"
fi
popd > /dev/null
shopt -u dotglob
echo "Completed exporting Git to RTC"


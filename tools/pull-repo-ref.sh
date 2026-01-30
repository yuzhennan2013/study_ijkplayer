#! /usr/bin/env bash

REMOTE_REPO=$1
LOCAL_WORKSPACE=$2
REF_REPO=$3

if [ -z $1 -o -z $2 -o -z $3 ]; then
    echo "invalid call pull-repo.sh '$1' '$2' '$3'"
elif [ ! -d $LOCAL_WORKSPACE ]; then
    # The git clone --reference <repository> command is used to efficiently clone a Git repository by borrowing objects from an existing local repository. This significantly reduces network data transfer and local storage consumption by avoiding redundant object copies. 
    # How It Works
    # When you use the --reference option, Git does not copy all objects from the source immediately. Instead, the new repository creates a pointer (stored in .git/objects/info/alternates) to the objects directory of the reference repository. 
    # If an object needed by the new clone is already present in the reference repository, it is simply "borrowed" via this pointer, rather than downloaded from the remote or copied locally. This can make the initial clone operation much faster, especially for large repositories or when working with many related local copies of the same upstream project. 
    #     Key Considerations
    # Dependency on Reference Repo: The newly cloned repository relies on the reference repository to function correctly. If the reference repository is moved, deleted, or corrupted, the new clone will become broken, issuing errors like error: object directory ... does not exist.
    # ** --dissociate Option**: To use a reference repository to speed up the initial clone but then remove the dependency afterward, you can add the --dissociate option. This command copies any remaining necessary objects locally after the clone is complete, making the new repository fully independent.
    # Network Optimization: This feature is particularly useful for optimizing clones of remote repositories where you already have a local cache of objects. 
    git clone --reference $REF_REPO $REMOTE_REPO $LOCAL_WORKSPACE
    cd $LOCAL_WORKSPACE
    git repack -a
else
    cd $LOCAL_WORKSPACE
    git fetch --all --tags
    cd -
fi

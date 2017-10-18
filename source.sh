dlc_home="$(pwd)"
alias dlc-check='kubectl --namespace=dlc-jupyterhub get pod'
alias dlc-resize=""

function dlc-resize {
    # https://zero-to-jupyterhub.readthedocs.io/en/latest/extending-jupyterhub.html#applying-configuration-changes
    gcloud container clusters resize deeplearning-codelab \
           --zone europe-west1-b \
           --size $1
}

function dlc-reload-config {
    # https://zero-to-jupyterhub.readthedocs.io/en/latest/extending-jupyterhub.html#applying-configuration-changes
    helm upgrade dlc-jupyterhub jupyterhub/jupyterhub \
         --version=v0.4 \
         -f "$dlc_home/config.yaml"
}

function _dlc-make-config {
    local secret="$(< .github-secret.key)"
    sed -e "s/%%TAG%%/$1/g" -e "s/%%GITHUBSECRET%%/$secret/g" \
        < "$dlc_home/config.yaml.template"
}

function dlc-upload {
    # https://zero-to-jupyterhub.readthedocs.io/en/latest/user-experience.html#build-a-custom-image-with-repo2docker
    local commit_id="$(cd "$dlc_home" ; git rev-parse HEAD)"
    local short_commit_id="${commit_id:0:6}"
    echo "Using $short_commit_id as tag"
    echo "Building Docker image with repo2docker"
    jupyter-repo2docker \
        . \
        --image=gcr.io/deeplearning-codelab-183309/workspace:$short_commit_id \
        --no-run
    echo "Uploading Docker image on gcloud"
    gcloud docker -- \
           push gcr.io/deeplearning-codelab-183309/workspace:$short_commit_id
    echo "Updating config file"
    _dlc-make-config $short_commit_id > "$dlc_home/config.yaml"
    echo "Upload new config file"
    dlc-reload-config
}

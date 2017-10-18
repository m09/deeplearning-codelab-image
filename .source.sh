dlc_home="$(pwd)"
alias dlc-check='kubectl --namespace=dlc-jupyterhub get pod'

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
         -f "$dlc_home/.config.yaml"
}

function _dlc-get-tag {
    local commit_id="$(cd "$dlc_home" ; git rev-parse HEAD)"
    echo "${commit_id:0:6}"
}

function dlc-make-config {
    local tag="$(_dlc-get-tag)"
    local github_secret="$(< .github-secret.key)"
    local hub_secret="$(< .hub-secret.key)"
    local proxy_secret="$(< .proxy-secret.key)"
    sed -e "s/%%TAG%%/$tag/g" \
        -e "s/%%GITHUBSECRET%%/$github_secret/g" \
        -e "s/%%HUBSECRET%%/$hub_secret/g" \
        -e "s/%%PROXYSECRET%%/$proxy_secret/g" \
        < "$dlc_home/.config.yaml.template" \
        > "$dlc_home/.config.yaml"
}

function dlc-upload {
    # https://zero-to-jupyterhub.readthedocs.io/en/latest/user-experience.html#build-a-custom-image-with-repo2docker
    local tag="$(_dlc-get-tag)"
    echo "Using $tag as tag"
    echo "Building Docker image with repo2docker"
    jupyter-repo2docker \
        "$dlc_home" \
        --image=gcr.io/deeplearning-codelab-183309/workspace:$tag \
        --no-run
    echo "Uploading Docker image on gcloud"
    gcloud docker -- \
           push gcr.io/deeplearning-codelab-183309/workspace:$tag
    echo "Updating config file"
    dlc-make-config
    echo "Upload new config file"
    dlc-reload-config
}

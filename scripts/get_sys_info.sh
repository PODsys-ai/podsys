#!/bin/bash

get_distribution_name() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        distro="$NAME"
        version="$VERSION_ID"
    elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ] || [ -f /etc/fedora-release ]; then
        # RHEL,CentOS,Fedora
        distro=$(cat /etc/{redhat,centos,fedora}-release | cut -d ' ' -f 1)
        version=$(cat /etc/{redhat,centos,fedora}-release | awk '{print $3}')
    elif [ -f /etc/SuSE-release ] || [ -f /etc/openSUSE-release ]; then
        # SUSE,openSUSE
        distro=$(head -n 1 /etc/SuSE-release | awk '{print $1}')
        version=$(grep VERSION_ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
    else
        distro="Unknown"
        version="Unknown"
    fi
}

get_distribution_name

case $distro in
    Ubuntu)
        if [[ "$version" =~ ^22.04\.5$ ]]; then
            echo "Ubuntu 22.04.5 LTS"
        else
            echo "Ubuntu $version"
        fi
        ;;
    CentOS)
        echo "CentOS $version"
        ;;
    Red*|Fedora|Oracle*)
        echo "${distro}:$version"
        ;;
    *)
        echo "Unknown Linux: $distro"
        ;;
esac
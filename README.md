# Light-weight Exegol images
This is a fork of the original [Exegol-Images project](https://github.com/ThePorgs/Exegol-Images).
The objective is to get rid of unused exegol features that I do not personally use and that are taking so much disk space on the original images. Do not get me wrong, it is a good idea to provide everything you could need in Exegol, but having images that are taking more than 10% was a bit problematic for me. So I decided to dive into Exegol-Images and remove the features and programs I don't use.

## What did I do?
I removed unused feature from the `sources/dockerfiles/*.dockerfile`. I juste worked on `base`, `ad` and `web` images.

## Using Docker caching functionality
During development, it was very hard to make quick tests because of the way the images are built. Indeed, the whole installation process is contained into a single bash function. Therefore, an error in the function leads to the whole installation process failing, even huge `apt install`. Developers  I decided to remake the Dockerfile to be able to use docker caching feature. This has the cons of making a big Dockerfile but at least you don't need to rewait half an hour if the installation fails at the end.

## What if a tool is missing?
Exegol-Images is using a smart way to install tools. Each tool installation is written inside a bash function. When build the images, all the function are loaded and the function are called, installing what is needed. During post installation, all the install scripts are removed. 

In my version, the install scripts are not removed, even better the function are loaded in you `.zshrc`. This means if you need a tool, you can install it the *Exegol way* by running `install_TOOLNAME`.

----------------------------

*Below this is the original Exegol-Images README.*

-----------------------------

> **📌 This repository hosts code for Exegol images, a submodule of the Exegol project. 
> If you were looking for Exegol, go to [the main repo](https://github.com/ThePorgs/Exegol)**
___

# Exegol images

This repository hosts Dockerfiles for each Exegol image, an installation script, and various assets needed during the installation (custom configurations, a history file, an aliases file, etc.). These files can be used to locally build the docker images, there is however a pipeline in place to build, test and push images on DockerHub so that Exegol users don't have to build their own image.

More information on [the Exegol documentation](https://exegol.readthedocs.io/en/latest/the-exegol-project/docker-images.html).

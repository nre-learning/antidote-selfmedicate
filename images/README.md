# images

This folder can store pre-downloaded images for use with vagrant.  Once the images are loaded, to save to the images folder from within the vagrant environment.

```vagrant ssh -c "docker save antidotelabs/utility | gzip > /images/utility.tar.gz"```
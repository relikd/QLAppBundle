![macOS 10.15+](https://img.shields.io/badge/macOS-10.15+-888)
[![Current release](https://img.shields.io/github/release/relikd/QLAppBundle)](https://github.com/relikd/QLAppBundle/releases)
[![GitHub license](https://img.shields.io/github/license/relikd/QLAppBundle)](LICENSE)


QLAppBundle
===========

A QuickLook plugin for app bundles (`.ipa`, `.tipa`, `.appex`, `.xcarchive`, `.apk`).

![QuickLook for IPA file](screenshot.png)
![QuickLook for APK file](screenshot2.png)


## Why?

I have been using [ProvisionQL][1].
In fact, I have contributed a lot of time and effort into a [pull request][2] to improve features and fix bugs.
But my PR is still open after 1 ½ years and there is still no support for macOS 15.
I know the author is working on it but it still takes too long for me.
So here it goes, my own fork to maintain.

This is not to devalue the original code, I highly respect the authors contribution for the general public.
I merely want things to be done.
Also, I've removed support for provisioning profiles (`.mobileprovision`, `.provisionprofile`) to focus on app bundles.



## ToDo

- [x] support for `.apk` files



## Features

### Customize HTML / CSS

1. Right click on the app and select "Show Package Contents"
2. Copy `Contents/Resources/template.html` (or `style.css`)
3. Open `~/Library/Containers/de.relikd.QLAppBundle.Preview/Data/Documents/`
4. Paste the previous file and modify it to your liking
5. `QLAppBundle` will use the new file from now on



## Development notes

### Debug

You can show Console logs with `subsystem:de.relikd.QLAppBundle`


[1]: https://github.com/ealeksandrov/ProvisionQL
[2]: https://github.com/ealeksandrov/ProvisionQL/pull/54

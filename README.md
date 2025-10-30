![macOS 10.15+](https://img.shields.io/badge/macOS-10.15+-888)
[![Current release](https://img.shields.io/github/release/relikd/QLApps)](https://github.com/relikd/QLApps/releases)
[![GitHub license](https://img.shields.io/github/license/relikd/QLApps)](LICENSE)


QLApps
======

A QuickLook plugin for app bundles (`.ipa`, `.appex`, `.xcarchive`).

![screenshot](screenshot.png)


## Why?

I have been using [ProvisionQL][1].
In fact, I have contributed a lot of time and effort into a [pull request][2] to improve features and fix bugs.
But my PR is still open after 1 ½ years and there is still no support for macOS 15.
I know the author is working on it but it still takes too long for me.
So here it goes, my own fork to maintain.

This is not to devalue the original code, I highly respect the authors contribution for the general public.
I merely want things to be done.
Also, I've removed support for provisioning profiles (`.mobileprovision`, `.provisionprofile`) and focus on app bundles.


## Future

If I find the time, I'll add support for `.apk` files too.


[1]: https://github.com/ealeksandrov/ProvisionQL
[2]: https://github.com/ealeksandrov/ProvisionQL/pull/54

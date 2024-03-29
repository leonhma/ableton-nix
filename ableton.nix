{ stdenv
, lib
, mkWindowsApp
, wine
, fetchurl
, makeDesktopItem
, makeDesktopIcon   # This comes with erosanix. It's a handy way to generate desktop icons.
, copyDesktopItems
, copyDesktopIcons  # This comes with erosanix. It's a handy way to generate desktop icons.
, unzip
, makeWrapper }: let
  # The default settings used if user doesn't already have a settings file.
  # Tabs are disabled because they lead to UI issues when using Wine.

  # This registry file sets winebrowser (xdg-open) as the default handler for
  # text files, instead of Wine's notepad.
  # Selecting "Settings -> Advanced Options" should then use xdg-open to open the SumatraPDF config file.
in mkWindowsApp rec {
  inherit wine;

  pname = "ableton";
  version = "11.3.21";

  src = builtins.fetchurl {  # use builtins for nice download progress
    url = "https://cdn-downloads.ableton.com/channels/${version}/ableton_live_lite_${version}_64.zip";
    sha256 = "1hlfxg67zlcblvfy41yw3m5v518fv1a8v2ghf2wf7xy5iysxp8j7";
  };

  # In most cases, you'll either be using an .exe or .zip as the src.
  # Even in the case of a .zip, you probably want to unpack with the launcher script.
  dontUnpack = true;   

  # You need to set the WINEARCH, which can be either "win32" or "win64".
  # Note that the wine package you choose must be compatible with the Wine architecture.
  wineArch = "win64";

  # Sometimes it can take a while to install an application to generate an app layer.
  # `enableInstallNotification`, which is set to true by default, uses notify-send
  # to generate a system notification so that the user is aware that something is happening.
  # There are two notifications: one before the app installation and one after.
  # The notification will attempt to use the app's icon, if it can find it. And will fallback
  # to hard-coded icons if needed.
  # If an app installs quickly, these notifications can actually be distracting.
  # In such a case, it's better to set this option to false.
  # This package doesn't benefit from the notifications, but I've explicitly enabled them
  # for demonstration purposes.
  enableInstallNotification = true;

  # `fileMap` can be used to set up automatic symlinks to files which need to be persisted.
  # The attribute name is the source path and the value is the path within the $WINEPREFIX.
  # But note that you must ommit $WINEPREFIX from the path.
  # To figure out what needs to be persisted, take at look at $(dirname $WINEPREFIX)/upper,
  # while the app is running. config and cache
  fileMap = { 
    "$HOME/.config/Ableton" = "drive_c/users/$USER/AppData/Roaming/Ableton";
  };

  # By default, `fileMap` is applied right before running the app and is cleaned up after the app terminates. If the following option is set to "true", then `fileMap` is also applied prior to `winAppInstall`. This is set to "false" by default.
  fileMapDuringAppInstall = true;

  # By default `mkWindowsApp` doesn't persist registry changes made during runtime. Therefore, if an app uses the registry then set this to "true". The registry files are saved to `$HOME/.local/share/mkWindowsApp/$pname/`.
  persistRegistry = true;

  # By default mkWindowsApp creates ephemeral (temporary) WINEPREFIX(es). 
  # Setting persistRuntimeLayer to true causes mkWindowsApp to retain the WINEPREFIX, for the short term. 
  # This option is designed for apps which can't have their automatic updates disabled.
  # It allows package maintainers to not have to constantly update their mkWindowsApp packages.
  # It is NOT meant for long-term persistance; If the Windows or App layers change, the Runtime layer will be discarded.
  persistRuntimeLayer = true;

  # The method used to calculate the input hashes for the layers.
  # This should be set to "store-path", which is the strictest and most reproduceable method. But it results in many rebuilds of the layers since the slightest change to the package inputs will change the input hashes.
  # An alternative is "version" which is a relaxed method and results in fewer rebuilds but is less reproduceable. If you are considering using "version", contact me first. There may be a better way.
  inputHashMethod = "store-path";

  # provide unzip during installation (in runtime), wait for responding prompts (it just takes a while)
  buildInputs = [ copyDesktopItems copyDesktopIcons ];

  # This code will become part of the launcher script.
  # It will execute if the application needs to be installed,
  # which would happen either if the needed app layer doesn't exist,
  # or for some reason the needed Windows layer is missing, which would
  # invalidate the app layer.
  # WINEPREFIX, WINEARCH, AND WINEDLLOVERRIDES are set
  # and wine, winetricks, and cabextract are in the environment.
  winAppInstall = ''
    d="$WINEPREFIX/drive_c/${pname}_install"
    PATH="$PATH:${lib.makeBinPath ([ unzip ])}"

    mkdir -p "$d"
    unzip ${src} -d "$d"
    wine "$d/Ableton Live 11 Lite Installer.exe"
    rm -rf "$d"
  '';


  # This code runs before winAppRun, but only for the first instance.
  # Therefore, if the app is already running, winAppRun will not execute.
  # Use this to do any setup prior to running the app.
  winAppPreRun = ''
  '';

  # This code will become part of the launcher script.
  # It will execute after winAppInstall and winAppPreRun (if needed),
  # to run the application.
  # WINEPREFIX, WINEARCH, AND WINEDLLOVERRIDES are set
  # and wine, winetricks, and cabextract are in the environment.
  # Command line arguments are in $ARGS, not $@
  # DO NOT BLOCK. For example, don't run: wineserver -w
  # DO NOT change the default install location (C:/ProgramData/Ableton/Live 11 Lite/Program/)
  winAppRun = ''
    wine "$WINEPREFIX/drive_c/ProgramData/Ableton/Live 11 Lite/Program/Ableton Live 11 Lite.exe"
  '';

  # This code will run after winAppRun, but only for the first instance.
  # Therefore, if the app was already running, winAppPostRun will not execute.
  # In other words, winAppPostRun is only executed if winAppPreRun is executed.
  # Use this to do any cleanup after the app has terminated
  winAppPostRun = "";

  # This is a normal mkDerivation installPhase, with some caveats.
  # The launcher script will be installed at $out/bin/.launcher
  # DO NOT DELETE OR RENAME the launcher. Instead, link to it as shown.
  installPhase = ''
    runHook preInstall

    ln -s $out/bin/.launcher $out/bin/${pname}

    runHook postInstall
  '';

  desktopItems = let
    mimeTypes = [ ];
  in [
    (makeDesktopItem {
      inherit mimeTypes;

      name = pname;
      exec = pname;
      icon = pname;
      desktopName = "Ableton Live 11 Lite";
      genericName = "Music Production Software";
      categories = ["Audio" "Midi" "Sequencer" "Music" "AudioVideo" ];
    })
  ];

  desktopIcon = makeDesktopIcon {
    name = "ableton";

    src = ./ableton-256.png;
  };

  meta = with lib; {
    description = "Well-known music production software.";
    homepage = "https://www.ableton.com/en/products/live-lite/";
    platforms = [ "x86_64-linux" ];
  };
}
#!/bin/bash

# This should allow Blueprint to run in docker. Please note that changing the $FOLDER variable after running
# the Blueprint installation script will not change anything in any files besides blueprint.sh.
  FOLDER="pterodactyl"

if [[ -f ".dockerenv" ]]; then
  DOCKER="y";
  FOLDER="html"
fi;

# If the fallback version below does not match your downloaded version, please let us know.
  VER_FALLBACK="alpha-T0R";

# This will be automatically replaced by some marketplaces, if not, $VER_FALLBACK will be used as fallback.
  PM_VERSION="([(pterodactylmarket_version)])";

if [[ -d "/var/www/$FOLDER/blueprint" ]]; then mv /var/www/$FOLDER/blueprint /var/www/$FOLDER/.blueprint; fi;

# BUILT_FROM_SOURCE="y"; # If you downloaded Blueprint from a release instead of building it, this should be "n".
# if [[ $BUILT_FROM_SOURCE == "y" ]]; then if [[ ! -f "/var/www/$FOLDER/.blueprint/.storage/versionschemefix.flag" ]]; then sed -E -i "s*&bp.version&*source*g" app/Services/Helpers/BlueprintPlaceholderService.php;touch /var/www/$FOLDER/.blueprint/.storage/versionschemefix.flag;fi;VERSION="source";

if [[ $PM_VERSION == "([(pterodactylmarket""_version)])" ]]; then
  # This runs when the placeholder has not changed, indicating an issue with PterodactylMarket
  # or Blueprint being installed from other sources.
  if [[ ! -f "/var/www/$FOLDER/.blueprint/.storage/versionschemefix.flag" ]]; then
    sed -E -i "s*&bp.version&*$VER_FALLBACK*g" app/Services/Helpers/BlueprintPlaceholderService.php;
    sed -E -i "s*@version*$VER_FALLBACK*g" public/extensions/blueprint/index.html;
    touch /var/www/$FOLDER/.blueprint/.storage/versionschemefix.flag;
  fi;
  
  VERSION=$VER_FALLBACK;
elif [[ $PM_VERSION != "([(pterodactylmarket""_version)])" ]]; then
  # This runs in case it is possible to use the PterodactylMarket placeholder instead of the
  # fallback version.
  if [[ ! -f "/var/www/$FOLDER/.blueprint/.storage/versionschemefix.flag" ]]; then
    sed -E -i "s*&bp.version&*$PM_VERSION*g" app/Services/Helpers/BlueprintPlaceholderService.php;
    sed -E -i "s*@version*$PM_VERSION*g" public/extensions/blueprint/index.html;
    touch /var/www/$FOLDER/.blueprint/.storage/versionschemefix.flag;
  fi;

  VERSION=$PM_VERSION;
fi;

# Fix for Blueprint's bash database to work with docker and custom folder installations.
sed -i "s!&bp.folder&!$FOLDER!g" /var/www/$FOLDER/.blueprint/lib/db.sh;

cd /var/www/$FOLDER;
source .blueprint/lib/bash_colors.sh;
source .blueprint/lib/parse_yaml.sh;
source .blueprint/lib/db.sh;

if [[ "$@" == *"-php"* ]]; then
  exit 1;
fi;

export NEWT_COLORS='
  root=,black
  window=black,red
  title=white,red
  border=red,red
  textbox=white,red
  listbox=white,black
  button=white,red
';

error() {
  whiptail --title " Blueprint " --ok-button "ok" --msgbox "Sorry, this operation could not be completed. For troubleshooting, please go to ptero.shop/error.\n\n\"${1}\"" 15 60;
  log_red "${1}";
  exit 1;
};

touch /usr/local/bin/blueprint > /dev/null;
echo -e "#!/bin/bash\nbash /var/www/$FOLDER/blueprint.sh -bash \$@;" > /usr/local/bin/blueprint;
chmod u+x /var/www/$FOLDER/blueprint.sh > /dev/null;
chmod u+x /usr/local/bin/blueprint > /dev/null;

if [[ $1 != "-bash" ]]; then
  if dbValidate "blueprint.setupFinished"; then
    log_blue "This command only works if you have yet to install Blueprint. You can run \"\033[1;94mblueprint\033[0m\033[0;34m\" instead.";
    exit 1;
  else
    log "  ██\n██  ██\n  ████\n";
    if [[ $DOCKER == "y" ]]; then
      log_red "Running Blueprint with Docker may result in issues.";
    fi;

    sed -i "s!&bp.folder&!$FOLDER!g" /var/www/$FOLDER/app/Services/Helpers/BlueprintPlaceholderService.php;
    sed -i "s!&bp.folder&!$FOLDER!g" /var/www/$FOLDER/resources/views/layouts/admin.blade.php;

    log_bright "php artisan down";
    php artisan down;

    log_bright "/var/www/$FOLDER/public/themes/pterodactyl/css/pterodactyl.css";
    sed -i "s!@import 'checkbox.css';!@import 'checkbox.css';\n@import url(/assets/extensions/blueprint/blueprint.style.css);\n/* blueprint reserved line */!g" /var/www/$FOLDER/public/themes/pterodactyl/css/pterodactyl.css;


    log_bright "php artisan view:clear";
    php artisan view:clear;


    log_bright "php artisan config:clear";
    php artisan config:clear;


    log_bright "php artisan migrate";
    php artisan migrate;


    log_bright "chown -R www-data:www-data /var/www/$FOLDER/*";
    chown -R www-data:www-data /var/www/$FOLDER/*;

    log_bright "chown -R www-data:www-data /var/www/$FOLDER/.*";
    chown -R www-data:www-data /var/www/$FOLDER/.*;

    log_bright "rm .blueprint/.development/.hello.txt";
    rm .blueprint/.development/.hello.txt;

    log_bright "php artisan up";
    php artisan up;

    log_green "\n\nBlueprint should now be installed. If something didn't work as expected, please let us know at discord.gg/CUwHwv6xRe.";

    dbAdd "blueprint.setupFinished";
    exit 1;
  fi;
fi;

if [[ ( $2 == "-i" ) || ( $2 == "-install" ) ]]; then
  log_bright "Always make sure you place your extensions in the Pterodactyl directory, else Blueprint won't be able to find them!";

  if [[ $(expr $# - 2) != 1 ]]; then error "Expected 1 argument but got $(expr $# - 2).";fi;
  if [[ $3 == "test␀" ]]; then
    dev=true;
    n="dev";
    mkdir .blueprint/.storage/tmp/dev;
    cp -R .blueprint/.development/* .blueprint/.storage/tmp/dev/;
  else
    dev=false;
    n=$3;
    FILE=$n".blueprint"
    if [[ ! -f "$FILE" ]]; then error "$FILE could not be found.";fi;

    ZIP=$n".zip";
    cp $FILE .blueprint/.storage/tmp/$ZIP;
    cd .blueprint/.storage/tmp;
    unzip $ZIP;
    rm $ZIP;
    if [[ ! -f "$n/*" ]]; then
      cd ..;
      rm -R tmp;
      mkdir tmp;
      cd tmp;

      mkdir ./$n;
      cp ../../../$FILE ./$n/$ZIP;
      cd $n;
      unzip $ZIP;
      rm $ZIP;
      cd ..;
    fi;
  fi;


  cd /var/www/$FOLDER;

  eval $(parse_yaml .blueprint/.storage/tmp/$n/conf.yml)

  if [[ $dev ]]; then
    mv .blueprint/.storage/tmp/$n .blueprint/.storage/tmp/$identifier;
    n=$identifier;
  fi;

  if [[ $flags != *"-placeholders.skip;"* ]]; then
    DIR=.blueprint/.storage/tmp/$n/*;

    if [[ $flags == *"-disable_az_placeholders;"* ]]; then
      SKIPAZPLACEHOLDERS=true;
      echo "A-Z placeholders will be skipped due to the '-disable_az_placeholders;' flag.";
    else
      SKIPAZPLACEHOLDERS=false;
    fi;

    for f in $(find $DIR -type f -exec echo {} \;); do
      sed -i "s~\^#version#\^~$version~g" $f;
      sed -i "s~\^#author#\^~$author~g" $f;
      sed -i "s~\^#identifier#\^~$identifier~g" $f;
      sed -i "s~\^#path#\^~/var/www/$FOLDER~g" $f;
      sed -i "s~\^#datapath#\^~/var/www/$FOLDER/.blueprint/.storage/extensiondata/$identifier~g" $f;

      if [[ $SKIPAZPLACEHOLDERS != true ]]; then
        sed -i "s~bpversionreplace~$version~g" $f;
        sed -i "s~bpauthorreplace~$author~g" $f;
        sed -i "s~bpidentifierreplace~$identifier~g" $f;
        sed -i "s~bppathreplace~/var/www/$FOLDER~g" $f;
        sed -i "s~bpdatapathreplace~/var/www/$FOLDER/.blueprint/.storage/extensiondata/$identifier~g" $f;
      fi;

      echo "Done placeholders in '$f'.";
    done;

  else echo "-placeholders.skip;"; fi;

  if [[ $name == "" ]]; then rm -R .blueprint/.storage/tmp/$n; error "'name' is a required option.";fi;
  if [[ $identifier == "" ]]; then rm -R .blueprint/.storage/tmp/$n; error "'identifier' is a required option.";fi;
  if [[ $description == "" ]]; then rm -R .blueprint/.storage/tmp/$n; error "'description' is a required option.";fi;
  if [[ $version == "" ]]; then rm -R .blueprint/.storage/tmp/$n; error "'version' is a required option.";fi;
  if [[ $target == "" ]]; then rm -R .blueprint/.storage/tmp/$n; error "'target' is a required option.";fi;
  if [[ $icon == "" ]]; then rm -R .blueprint/.storage/tmp/$n; error "'icon' is a required option.";fi;

  if [[ $datafolder_directory == "" ]]; then log "Datafolder left blank, skipping..";fi;

  if [[ $controller_location == "" ]]; then log "Controller location left blank, using default controller instead..";controller_type="default";fi;
  if [[ $view_location == "" ]]; then rm -R .blueprint/.storage/tmp/$n; error "'view_location' is a required option.";fi;

  if [[ $target != $VERSION ]]; then log_red "This extension is built for version $target, but your version is $VERSION.";fi;
  if [[ $identifier != $n ]]; then rm -R .blueprint/.storage/tmp/$n; error "The extension identifier should be exactly the same as your .blueprint file (just without the .blueprint). This may be subject to change, but is currently required.";fi;
  if [[ $identifier == "blueprint" ]]; then rm -R .blueprint/.storage/tmp/$n; error "The operation could not be completed since the extension is attempting to overwrite internal files.";fi;

  if [[ $identifier =~ [a-z] ]]; then echo "ok";
  else rm -R .blueprint/.storage/tmp/$n; error "The extension identifier should be lowercase and only contain characters a-z.";fi;

  if [[ ! -f ".blueprint/.storage/tmp/$n/$icon" ]]; then rm -R .blueprint/.storage/tmp/$n;error "The 'icon' path points to a nonexisting file.";fi;

  if [[ $migrations_directory != "" ]]; then
    if [[ $migrations_enabled == "yes" ]]; then
      cp -R .blueprint/.storage/tmp/$n/$migrations_directory/* database/migrations/ 2> /dev/null;
    elif [[ $migrations_enabled == "no" ]]; then
      echo "ok";
    else
      rm -R .blueprint/.storage/tmp/$n;
      error "If defined, migrations_enabled should only be 'yes' or 'no'.";
    fi;
  fi;

  if [[ $css_location != "" ]]; then
    if [[ $css_enabled == "yes" ]]; then
      INJECTCSS="y";
    elif [[ $css_enabled == "no" ]]; then
      echo "ok";
    else
      rm -R .blueprint/.storage/tmp/$n;
      error "If defined, css_enabled should only be 'yes' or 'no'.";
    fi;
  fi;

  if [[ $adminrequests_directory != "" ]]; then
    if [[ $adminrequests_enabled == "yes" ]]; then
      mkdir app/Http/Requests/Admin/Extensions/$identifier;
      cp -R .blueprint/.storage/tmp/$n/$adminrequests_directory/* app/Http/Requests/Admin/Extensions/$identifier/ 2> /dev/null;
    elif [[ $adminrequests_enabled == "no" ]]; then
      echo "ok";
    else
      rm -R .blueprint/.storage/tmp/$n;
      error "If defined, adminrequests_enabled should only be 'yes' or 'no'.";
    fi;
  fi;

  if [[ $publicfiles_directory != "" ]]; then
    if [[ $publicfiles_enabled == "yes" ]]; then
      mkdir public/extensions/$identifier;
      cp -R .blueprint/.storage/tmp/$n/$publicfiles_directory/* public/extensions/$identifier/ 2> /dev/null;
    elif [[ $publicfiles_enabled == "no" ]]; then
      echo "ok";
    else
      rm -R .blueprint/.storage/tmp/$n;
      error "If defined, publicfiles_enabled should only be 'yes' or 'no'.";
    fi;
  fi;

  cp -R .blueprint/.storage/defaults/extensions/admin.default .blueprint/.storage/defaults/extensions/admin.default.bak 2> /dev/null;
  if [[ $controller_type != "" ]]; then
    if [[ $controller_type == "default" ]]; then
      cp -R .blueprint/.storage/defaults/extensions/controller.default .blueprint/.storage/defaults/extensions/controller.default.bak 2> /dev/null;
    elif [[ $controller_type == "custom" ]]; then
      echo "ok";
    else
      rm -R .blueprint/.storage/tmp/$n;
      error "If defined, controller_type should only be 'default' or 'custom'.";
    fi;
  fi;
  cp -R .blueprint/.storage/defaults/extensions/route.default .blueprint/.storage/defaults/extensions/route.default.bak 2> /dev/null;
  cp -R .blueprint/.storage/defaults/extensions/button.default .blueprint/.storage/defaults/extensions/button.default.bak 2> /dev/null;

  mkdir .blueprint/.storage/extensiondata/$identifier;
  if [[ $datafolder_directory != "" ]]; then
    cp -R .blueprint/.storage/tmp/$n/$datafolder_directory/* .blueprint/.storage/extensiondata/$identifier/;
  fi;

  mkdir public/assets/extensions/$identifier;
  cp .blueprint/.storage/tmp/$n/$icon public/assets/extensions/$identifier/icon.jpg;
  ICON="/assets/extensions/$identifier/icon.jpg";
  CONTENT=$(cat .blueprint/.storage/tmp/$n/$view_location);

  if [[ $INJECTCSS == "y" ]]; then
    sed -i "s!/* blueprint reserved line */!/* blueprint reserved line */\n@import url(/assets/extensions/$identifier/$identifier.style.css);!g" public/themes/pterodactyl/css/pterodactyl.css;
    cp -R .blueprint/.storage/tmp/$n/$css_location/* public/assets/extensions/$identifier/$identifier.style.css 2> /dev/null;
  fi;

  if [[ $name == *"~"* ]]; then log_red "'name' contains '~' and may result in an error.";fi;
  if [[ $description == *"~"* ]]; then log_red "'description' contains '~' and may result in an error.";fi;
  if [[ $version == *"~"* ]]; then log_red "'version' contains '~' and may result in an error.";fi;
  if [[ $CONTENT == *"~"* ]]; then log_red "'CONTENT' contains '~' and may result in an error.";fi;
  if [[ $ICON == *"~"* ]]; then log_red "'ICON' contains '~' and may result in an error.";fi;
  if [[ $identifier == *"~"* ]]; then log_red "'identifier' contains '~' and may result in an error.";fi;

  sed -i "s~␀title␀~$name~g" .blueprint/.storage/defaults/extensions/admin.default.bak;
  sed -i "s~␀name␀~$name~g" .blueprint/.storage/defaults/extensions/admin.default.bak;
  sed -i "s~␀breadcrumb␀~$name~g" .blueprint/.storage/defaults/extensions/admin.default.bak;
  sed -i "s~␀name␀~$name~g" .blueprint/.storage/defaults/extensions/button.default.bak;

  sed -i "s~␀description␀~$description~g" .blueprint/.storage/defaults/extensions/admin.default.bak;

  sed -i "s~␀version␀~$version~g" .blueprint/.storage/defaults/extensions/admin.default.bak;
  sed -i "s~␀version␀~$version~g" .blueprint/.storage/defaults/extensions/button.default.bak;

  sed -i "s~␀icon␀~$ICON~g" .blueprint/.storage/defaults/extensions/admin.default.bak;

  echo -e "$CONTENT\n@endsection" >> .blueprint/.storage/defaults/extensions/admin.default.bak;

  if [[ $controller_type != "custom" ]]; then
    sed -i "s~␀id␀~$identifier~g" .blueprint/.storage/defaults/extensions/controller.default.bak;
  fi;
  sed -i "s~␀id␀~$identifier~g" .blueprint/.storage/defaults/extensions/route.default.bak;
  sed -i "s~␀id␀~$identifier~g" .blueprint/.storage/defaults/extensions/button.default.bak;

  ADMINVIEW_RESULT=$(cat .blueprint/.storage/defaults/extensions/admin.default.bak);
  ADMINROUTE_RESULT=$(cat .blueprint/.storage/defaults/extensions/route.default.bak);
  ADMINBUTTON_RESULT=$(cat .blueprint/.storage/defaults/extensions/button.default.bak);
  if [[ $controller_type != "custom" ]]; then
    ADMINCONTROLLER_RESULT=$(cat .blueprint/.storage/defaults/extensions/controller.default.bak);
  fi;
  ADMINCONTROLLER_NAME=$identifier"ExtensionController.php";

  mkdir resources/views/admin/extensions/$identifier;
  touch resources/views/admin/extensions/$identifier/index.blade.php;
  echo $ADMINVIEW_RESULT > resources/views/admin/extensions/$identifier/index.blade.php;

  mkdir app/Http/Controllers/Admin/Extensions/$identifier;
  touch app/Http/Controllers/Admin/Extensions/$identifier/$ADMINCONTROLLER_NAME;

  if [[ $controller_type != "custom" ]]; then
    echo $ADMINCONTROLLER_RESULT > app/Http/Controllers/Admin/Extensions/$identifier/$ADMINCONTROLLER_NAME;
  else
    cp .blueprint/.storage/tmp/$n/$controller_location app/Http/Controllers/Admin/Extensions/$identifier/$ADMINCONTROLLER_NAME;
  fi;

  if [[ $controller_type == "custom" ]]; then
    cp .blueprint/.storage/tmp/$n/$controller_location app/Http/Controllers/Admin/Extensions/$identifier/${identifier}ExtensionController.php;
  fi;

  echo $ADMINROUTE_RESULT >> routes/admin.php;

  sed -i "s~<!--␀replace␀-->~$ADMINBUTTON_RESULT\n<!--␀replace␀-->~g" resources/views/admin/extensions.blade.php;

  rm .blueprint/.storage/defaults/extensions/admin.default.bak;
  if [[ $controller_type != "custom" ]]; then
    rm .blueprint/.storage/defaults/extensions/controller.default.bak;
  fi;
  rm .blueprint/.storage/defaults/extensions/route.default.bak;
  rm .blueprint/.storage/defaults/extensions/button.default.bak;
  rm -R .blueprint/.storage/tmp/$n;

  if [[ $author == "blueprint" ]]; then log_blue "Please refrain from setting the author variable to 'blueprint', thanks!";fi;
  if [[ $author == "Blueprint" ]]; then log_blue "Please refrain from setting the author variable to 'Blueprint', thanks!";fi;

  if [[ $migrations_enabled == "yes" ]]; then
    log_bold "This extension comes with migrations. If you get prompted, answer 'yes'.\n";
    php artisan migrate;
  fi;

  chmod -R +x .blueprint/.storage/extensiondata/$identifier/*;

  if [[ $flags == *"-run.afterinstall;"* ]]; then
    log_red "This extension uses a custom installation script, proceed with caution."
    bash .blueprint/.storage/extensiondata/$identifier/install.sh;
  fi;

  log_green "\n\n$identifier should now be installed. If something didn't work as expected, please let us know at discord.gg/CUwHwv6xRe.";
fi;

if [[ ( $2 == "help" ) || ( $2 == "-help" ) || ( $2 == "--help" ) ]]; then
   echo -e " -install -i  [name]      install a blueprint extension""
"           "-version -v              get the current blueprint version""
"           "-init                    initialize extension development files.""
"           "-build                   run an installation on your extension development files.""
"           "-export                  export your extension development files (experimental)""
"           "-reinstall               rerun the blueprint installation script""
"           "-upgrade                 update/reset to a newer version (experimental)";
fi;

if [[ ( $2 == "-v" ) || ( $2 == "-version" ) ]]; then
  echo -e $VERSION;
fi;

if [[ $2 == "-init" ]]; then
  echo "Name (Generic Extension):";             read ASKNAME;
  echo "Identifier (genericextension):";        read ASKIDENTIFIER;
  echo "Description (My awesome description):"; read ASKDESCRIPTION;
  echo "Version (indev):";                      read ASKVERSION;
  echo "Author (prplwtf):";                     read ASKAUTHOR;

  log "Validating..";
  if [[ $ASKIDENTIFIER =~ [a-z] ]]; then echo "ok" > /dev/null; else log "Identifier should only contain a-z characters.";exit 1;fi;

  log "Copying init defaults to tmp..";
  mkdir .blueprint/.storage/tmp/init;
  cp -R .blueprint/.storage/defaults/init/* .blueprint/.storage/tmp/init/;

  log "Applying variables.."
  sed -i "s~␀name␀~$ASKNAME~g" .blueprint/.storage/tmp/init/conf.yml; #NAME
  sed -i "s~␀identifier␀~$ASKIDENTIFIER~g" .blueprint/.storage/tmp/init/conf.yml; #IDENTIFIER
  sed -i "s~␀description␀~$ASKDESCRIPTION~g" .blueprint/.storage/tmp/init/conf.yml; #DESCRIPTION
  sed -i "s~␀ver␀~$ASKVERSION~g" .blueprint/.storage/tmp/init/conf.yml; #VERSION
  sed -i "s~␀author␀~$ASKAUTHOR~g" .blueprint/.storage/tmp/init/conf.yml; #AUTHOR

  icnNUM=$(expr 1 + $RANDOM % 3);
  sed -i "s~␀num␀~$icnNUM~g" .blueprint/.storage/tmp/init/conf.yml;
  sed -i "s~␀version␀~$VERSION~g" .blueprint/.storage/tmp/init/conf.yml;

  # Return files to folder.
  cp -R .blueprint/.storage/tmp/init/* .blueprint/.development/;

  # Remove tmp files
  rm -R .blueprint/.storage/tmp;
  mkdir .blueprint/.storage/tmp;

  log "Your extension files have been generated and exported to '.blueprint/.development'.";
fi;

if [[ ( $2 == "-build" ) || ( $2 == "-test" ) ]]; then
  if [[ $2 == "-test" ]]; then
    log_bright "-test will be removed in future versions, use -build instead.";
  fi
  log "Attempting to install extension files located in '.blueprint/.development'.";

  blueprint -i test␀;
fi;

if [[ $2 == "-export" ]]; then
  log_red "This is an experimental feature, proceed with caution.";
  log "Attempting to export extension files located in '.blueprint/.development'.";

  cd .blueprint
  zip .storage/tmp/blueprint.zip .development/*
  mv .storage/tmp/blueprint.zip ../extension.blueprint;

  log "Extension files should be exported into your Pterodactyl directory now. Some versions of Blueprint may require your identifier to match the filename (excluding the .blueprint extension). You'll need to do this manually.";
fi;

if [[ $2 == "-reinstall"  ]]; then
  dbRemove "blueprint.setupFinished";
  cd /var/www/$FOLDER;
  bash blueprint.sh;
fi;

if [[ $2 == "-upgrade" ]]; then
  log_red "This is an experimental feature, proceed with caution.\n";
  
  log_bright "Upgrading will wipe your .blueprint folder and will overwrite your extensions.
Are you sure you want to continue? (y/N)";
  read YN;
  if [[ ( $YN != "y" ) && ( $YN != "Y" ) ]]; then
    exit 1;
  fi;
  
  log_bright "Upgrading will use the latest source version of Blueprint.
This means that you will be using an early build of the next version that
might break. Upgrading is mainly made for Blueprint development not updating
to newer versions.
Are you sure you want to continue? (y/N)";
  read YN2;
  if [[ ( $YN2 == "y" ) || ( $YN2 == "Y" ) ]]; then
    log_bright "Upgrading..";
    bash tools/update.sh /var/www/$FOLDER;
    log_bright "Upgrade completed.";
  fi;
fi;

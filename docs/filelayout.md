# System Tree
This layout is a bit fluid and it will change but most of it is pretty solid
    

    mkdocs.yml    # The configuration file.
    docs/
        index.md  # The documentation homepage.
        ...       # Other markdown pages, images and other files.
    pnx3-1/
        debian/   # debian package builder
        etc/      # package installation code
        opt/      # code & wprkspaces
            pbx3/
                always/    # SQL always applied
                cache/     # build elements
                db/        # the database
                dbtabledumps/    #workspace for backups  
                etc/       # softlink library
                once/      # SQL applied only once when the DB is rebuilt
                php/
                           classes/         # classes used by the generator
                           generator/       # object generator for Asterisk files
                           utilities/       # various useful scripts 
                           provisioning/    # endpoint provisioning engine
                    config.php              # config file
                scripts/         # bash stuff
                service/         # runit tasks
        usr/
            share/
                    asterisk/
                        agi-bin
                            kwakeup         # wakeup call php agi

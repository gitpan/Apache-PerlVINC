#include "modules/perl/mod_perl.h"

static mod_perl_perl_dir_config *newPerlConfig(pool *p)
{
    mod_perl_perl_dir_config *cld =
	(mod_perl_perl_dir_config *)
	    palloc(p, sizeof (mod_perl_perl_dir_config));
    cld->obj = Nullsv;
    cld->pclass = "Apache::PerlVINC";
    register_cleanup(p, cld, perl_perl_cmd_cleanup, null_cleanup);
    return cld;
}

static void *create_dir_config_sv (pool *p, char *dirname)
{
    return newPerlConfig(p);
}

static void *create_srv_config_sv (pool *p, server_rec *s)
{
    return newPerlConfig(p);
}

static void stash_mod_pointer (char *class, void *ptr)
{
    SV *sv = newSV(0);
    sv_setref_pv(sv, NULL, (void*)ptr);
    hv_store(perl_get_hv("Apache::XS_ModuleConfig",TRUE), 
	     class, strlen(class), sv, FALSE);
}

static mod_perl_cmd_info cmd_info_PerlINC = { 
"Apache::PerlVINC::PerlINC", "", 
};
static mod_perl_cmd_info cmd_info_PerlVersion = { 
"Apache::PerlVINC::PerlVersion", "", 
};


static command_rec mod_cmds[] = {
    
    { "PerlINC", perl_cmd_perl_TAKE1,
      (void*)&cmd_info_PerlINC,
      OR_ALL, TAKE1, "A path to add to @INC" },

    { "PerlVersion", perl_cmd_perl_ITERATE,
      (void*)&cmd_info_PerlVersion,
      OR_ALL, ITERATE, "A file name" },

    { NULL }
};

module MODULE_VAR_EXPORT XS_Apache__PerlVINC = {
    STANDARD_MODULE_STUFF,
    NULL,               /* module initializer */
    create_dir_config_sv,  /* per-directory config creator */
    perl_perl_merge_dir_config,   /* dir config merger */
    create_srv_config_sv,       /* server config creator */
    NULL,        /* server config merger */
    mod_cmds,               /* command table */
    NULL,           /* [7] list of handlers */
    NULL,  /* [2] filename-to-URI translation */
    NULL,      /* [5] check/validate user_id */
    NULL,       /* [6] check user_id is valid *here* */
    NULL,     /* [4] check access by host address */
    NULL,       /* [7] MIME type checker/setter */
    NULL,        /* [8] fixups */
    NULL,             /* [10] logger */
    NULL,      /* [3] header parser */
    NULL,         /* process initializer */
    NULL,         /* process exit/cleanup */
    NULL,   /* [1] post read_request handling */
};

MODULE = Apache::PerlVINC		PACKAGE = Apache::PerlVINC

PROTOTYPES: DISABLE

BOOT:
    XS_Apache__PerlVINC.name = "Apache::PerlVINC";
    add_module(&XS_Apache__PerlVINC);
    stash_mod_pointer("Apache::PerlVINC", &XS_Apache__PerlVINC);

void
END()

    CODE:
    if (find_linked_module("Apache::PerlVINC")) {
        remove_module(&XS_Apache__PerlVINC);
    }

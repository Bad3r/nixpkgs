// LD_PRELOAD shim for Chromium and Electron apps on NixOS.
//
// The GPU process forks from the unsandboxed zygote, and its seccomp broker
// denies /run/opengl-driver, so libgbm's lazy dlopen of its backend fails
// with EACCES. In that zygote this shim dlopens the backends under the exact
// paths Mesa's loader builds, so the GPU process reuses the mapped copies.
// Other app processes map no Mesa code.
//
// GBM_ZYGOTE_PRELOAD_EXE names the app's executable. A process the app starts
// that is a different program removes the shim from its environment, so the
// shells, tools, and helpers the app runs never pass it on.

#define _GNU_SOURCE
#include <dirent.h>
#include <dlfcn.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define EXE_VAR "GBM_ZYGOTE_PRELOAD_EXE"
#define MAX_BACKENDS 64

static void load_backends(void) {
  static char seen[MAX_BACKENDS][NAME_MAX + 1];
  size_t nseen = 0;
  // Mesa searches nothing when the variable is set but empty.
  const char *paths = getenv("GBM_BACKENDS_PATH");
  char *list = strdup(paths ? paths : "/run/opengl-driver/lib/gbm");
  if (!list) return;
  for (char *save = NULL, *dir = strtok_r(list, ":", &save); dir;
       dir = strtok_r(NULL, ":", &save)) {
    DIR *d = opendir(dir);
    if (!d) continue;
    for (struct dirent *e; (e = readdir(d));) {
      size_t n = strlen(e->d_name), i;
      if (n < 7 || strcmp(e->d_name + n - 7, "_gbm.so") != 0) continue;
      // Mesa takes each backend name from the first directory that has it.
      for (i = 0; i < nseen && strcmp(seen[i], e->d_name) != 0; i++)
        ;
      if (i < nseen || nseen == MAX_BACKENDS) continue;
      char path[PATH_MAX];
      if (snprintf(path, sizeof path, "%s/%s", dir, e->d_name) >= (int)sizeof path)
        continue;
      if (dlopen(path, RTLD_NOW | RTLD_GLOBAL)) strcpy(seen[nseen++], e->d_name);
    }
    closedir(d);
  }
  free(list);
}

// Edits the initial environment in place: programs such as bash read the envp
// that main() receives, which setenv() would leave unchanged.
static void drop_from_environment(char **envp) {
  Dl_info info;
  const char *self = dladdr((void *)drop_from_environment, &info) ? info.dli_fname : NULL;
  size_t w = 0;
  for (size_t r = 0; envp[r]; r++) {
    char *e = envp[r];
    if (strncmp(e, EXE_VAR "=", sizeof EXE_VAR) == 0) continue;
    if (self && strncmp(e, "LD_PRELOAD=", 11) == 0) {
      char *val = e + 11, *copy = strdup(val);
      if (copy) {
        *val = 0;
        for (char *save = NULL, *p = strtok_r(copy, ": ", &save); p;
             p = strtok_r(NULL, ": ", &save)) {
          if (strcmp(p, self) == 0) continue;
          if (*val) strcat(val, ":");
          strcat(val, p);  // never longer than the original value
        }
        free(copy);
        if (!*val) continue;
      }
    }
    envp[w++] = e;
  }
  envp[w] = NULL;
}

static int is_app(const char *proc_exe, const char *app) {
  char exe[PATH_MAX];
  return realpath(proc_exe, exe) && strcmp(exe, app) == 0;
}

__attribute__((constructor)) static void gbm_zygote_preload(int argc, char **argv,
                                                            char **envp) {
  const char *var = getenv(EXE_VAR);
  char app[PATH_MAX], parent[64];
  if (!var || !realpath(var, app)) return;
  if (!is_app("/proc/self/exe", app)) {
    // Wrapper scripts that lead to the app keep the preload.
    snprintf(parent, sizeof parent, "/proc/%d/exe", (int)getppid());
    if (is_app(parent, app)) drop_from_environment(envp);
    return;
  }
  int zygote = 0, unsandboxed = 0;
  for (int i = 1; i < argc; i++) {
    zygote |= strcmp(argv[i], "--type=zygote") == 0;
    unsandboxed |= strcmp(argv[i], "--no-zygote-sandbox") == 0;
  }
  if (zygote && unsandboxed) load_backends();
}

#ifndef FAKE_SYS_AUXV_H
#define FAKE_SYS_AUXV_H

#include <elf.h>
#ifdef __LP64__
#define Elf_auxv_t Elf64_auxv_t
#else
#define Elf_auxv_t Elf32_auxv_t
#endif  // __LP64__
extern char** environ;

#define AT_SECURE (1UL)

static inline unsigned long getauxval(unsigned long type)
{
    char** envp = environ;
    while (*envp++ != nullptr) {}
    Elf_auxv_t* auxv = reinterpret_cast<Elf_auxv_t*>(envp);
    for (; auxv->a_type != AT_NULL; auxv++) {
        if (auxv->a_type == type) {
            return auxv->a_un.a_val;
        }
    }
    return 0;
}

#endif

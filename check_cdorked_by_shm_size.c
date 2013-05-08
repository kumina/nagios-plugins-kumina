// This program dumps the content of a shared memory block
// used by Linux/Cdorked.A into a file named httpd_cdorked_config.bin
// when the machine is infected.
//
// Some of the data is encrypted. If your server is infected and you
// would like to help, please send the httpd_cdorked_config.bin
// and your httpd executable to our lab for analysis. Thanks!
//
// Build with gcc -o dump_cdorked_config dump_cdorked_config.c
//
// Marc-Etienne M.Léveillé <leveille@eset.com>
//
// Modified and renamed so we can use it with Icinga
//                     -- Tim Stoop <tim@kumina.nl>

#include <stdio.h>
#include <sys/shm.h>

#define CDORKED_SHM_SIZE (6118512)

int main (int argc, char *argv[]) {
    int maxkey, id, shmid;
    struct shm_info shm_info;
    struct shmid_ds shmds;

    maxkey = shmctl(0, SHM_INFO, (void *) &shm_info);
    for(id = 0; id <= maxkey; id++) {
        shmid = shmctl(id, SHM_STAT, &shmds);
        if (shmid < 0)
            continue;

        if(shmds.shm_segsz == CDORKED_SHM_SIZE) {
            // We have a matching Cdorked memory segment
            printf("CRITICAL: A shared memory matching Cdorked signature was found.\n");
            return (2);
        }
    }
    printf("OK: No shared memory matching Cdorked signature was found.\n");
    return (0);
}

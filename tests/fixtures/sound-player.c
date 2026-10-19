/* Long-lived native fixture matching afplay/peon-play's stable exec identity. */
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static char marker[PATH_MAX];

static void stop(int signum) {
    (void)signum;
    unlink(marker);
    _exit(0);
}

int main(void) {
    const char *root = getenv("PEON_DIR");
    if (!root) return 1;
    if (snprintf(marker, sizeof marker, "%s/alive/%ld", root, (long)getpid()) >= (int)sizeof marker) return 1;
    struct sigaction action = {0};
    action.sa_handler = stop;
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGTERM, &action, NULL) || sigaction(SIGALRM, &action, NULL)) return 1;
    alarm(10); /* Bound fixture lifetime even if its test is interrupted. */
    int fd = open(marker, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (fd < 0) return 1;
    if (write(fd, "owned test audio", 16) != 16) stop(0);
    close(fd);
    char children[PATH_MAX];
    if (snprintf(children, sizeof children, "%s/children", root) >= (int)sizeof children) stop(0);
    fd = open(children, O_WRONLY | O_CREAT | O_APPEND, 0600);
    if (fd < 0) stop(0);
    dprintf(fd, "%ld\n", (long)getpid());
    close(fd);
    for (;;) pause();
}

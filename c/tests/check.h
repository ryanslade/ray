/* A minimal test harness: each CHECK that fails prints its location and
 * counts towards the exit status of the test program. */

#ifndef RAYTRACER_TEST_CHECK_H
#define RAYTRACER_TEST_CHECK_H

#include <stdio.h>
#include <stdlib.h>

static int check_failures = 0;

#define CHECK(cond)                                                                                \
    do {                                                                                           \
        if (!(cond)) {                                                                             \
            fprintf(stderr, "%s:%d: check failed: %s\n", __FILE__, __LINE__, #cond);               \
            check_failures++;                                                                      \
        }                                                                                          \
    } while (0)

#define RUN_TEST(fn)                                                                               \
    do {                                                                                           \
        int before = check_failures;                                                               \
        fn();                                                                                      \
        fprintf(stderr, "%s %s\n", check_failures == before ? "ok  " : "FAIL", #fn);               \
    } while (0)

#define CHECK_EXIT() (check_failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE)

#endif

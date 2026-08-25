#include <arpa/inet.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

typedef struct {
    const char *type;
    const char *filename;
} ICNSRepresentation;

static const ICNSRepresentation representations[] = {
    {"icp4", "icon_16x16.png"},
    {"icp5", "icon_32x32.png"},
    {"icp6", "icon_64x64.png"},
    {"ic07", "icon_128x128.png"},
    {"ic08", "icon_256x256.png"},
    {"ic09", "icon_512x512.png"},
    {"ic10", "icon_1024x1024.png"},
    {"ic11", "icon_32x32 1.png"},
    {"ic12", "icon_64x64.png"},
    {"ic13", "icon_256x256 1.png"},
    {"ic14", "icon_512x512 1.png"},
};

static int write_u32(FILE *output, uint32_t value) {
    uint32_t big_endian = htonl(value);
    return fwrite(&big_endian, sizeof(big_endian), 1, output) == 1 ? 0 : -1;
}

static int source_path(char *buffer, size_t capacity, const char *directory, const char *filename) {
    int written = snprintf(buffer, capacity, "%s/%s", directory, filename);
    return written >= 0 && (size_t)written < capacity ? 0 : -1;
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <AppIcon.appiconset> <output.icns>\n", argv[0]);
        return 64;
    }

    uint64_t total_size = 8;
    char path[4096];
    size_t representation_count = sizeof(representations) / sizeof(representations[0]);

    for (size_t index = 0; index < representation_count; index++) {
        if (source_path(path, sizeof(path), argv[1], representations[index].filename) != 0) {
            fprintf(stderr, "Icon source path is too long\n");
            return 1;
        }

        struct stat info;
        if (stat(path, &info) != 0 || info.st_size <= 0) {
            fprintf(stderr, "Unable to read %s: %s\n", path, strerror(errno));
            return 1;
        }
        total_size += 8 + (uint64_t)info.st_size;
    }

    if (total_size > UINT32_MAX) {
        fprintf(stderr, "ICNS output is too large\n");
        return 1;
    }

    FILE *output = fopen(argv[2], "wb");
    if (output == NULL) {
        fprintf(stderr, "Unable to create %s: %s\n", argv[2], strerror(errno));
        return 1;
    }

    if (fwrite("icns", 4, 1, output) != 1 || write_u32(output, (uint32_t)total_size) != 0) {
        fprintf(stderr, "Unable to write ICNS header\n");
        fclose(output);
        return 1;
    }

    unsigned char buffer[64 * 1024];
    for (size_t index = 0; index < representation_count; index++) {
        if (source_path(path, sizeof(path), argv[1], representations[index].filename) != 0) {
            fclose(output);
            return 1;
        }

        struct stat info;
        if (stat(path, &info) != 0) {
            fclose(output);
            return 1;
        }

        FILE *input = fopen(path, "rb");
        if (input == NULL) {
            fprintf(stderr, "Unable to open %s: %s\n", path, strerror(errno));
            fclose(output);
            return 1;
        }

        if (fwrite(representations[index].type, 4, 1, output) != 1
            || write_u32(output, (uint32_t)info.st_size + 8) != 0) {
            fclose(input);
            fclose(output);
            return 1;
        }

        size_t bytes_read;
        while ((bytes_read = fread(buffer, 1, sizeof(buffer), input)) > 0) {
            if (fwrite(buffer, 1, bytes_read, output) != bytes_read) {
                fclose(input);
                fclose(output);
                return 1;
            }
        }
        fclose(input);
    }

    if (fclose(output) != 0) {
        fprintf(stderr, "Unable to finish %s: %s\n", argv[2], strerror(errno));
        return 1;
    }

    return 0;
}

#!/usr/bin/env python3
import frontmatter
import os
import shutil

recipe_directory = "_rezepte"
output_directories = ['owners', 'tags']

for directory in output_directories:
    shutil.rmtree(directory, ignore_errors=True, onerror=None)

with os.scandir(recipe_directory) as entries:
    for entry in entries:
        if not entry.is_file():
            continue

        recipe = frontmatter.load(entry.path)
        for tag in recipe['tags']:
            dir = f'tags/{tag}'
            os.makedirs(dir, exist_ok=True)
            os.symlink(
                os.path.relpath(entry.path, start=dir),
                os.path.join(dir, entry.name)
            )

        owner = recipe['owner']
        dir = f'owners/{owner}'
        os.makedirs(dir, exist_ok=True)
        os.symlink(
            os.path.relpath(entry.path, start=dir),
            os.path.join(dir, entry.name)
        )

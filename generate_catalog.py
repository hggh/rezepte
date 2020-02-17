#!/usr/bin/env python3
import frontmatter
import os
import shutil

recipe_directory = "rezepte"
output_directories = ['owner', 'tags']

for directory in output_directories:
    shutil.rmtree(directory, ignore_errors=True, onerror=None)

tree = {
    'owner': {},
    'tags': {}
}
recipes = {}


with os.scandir(recipe_directory) as entries:
    for entry in entries:
        if not entry.is_file():
            continue
        file_name = entry.name
        recipe = frontmatter.load(entry.path)
        for category in recipe.keys():
            items = recipe[category]
            if not isinstance(items, list):
                items = [items]
            for item in items:
                os.makedirs(os.path.join(category, item), exist_ok=True)
                file = os.path.join(category, item, file_name)
                with open(file, 'w+') as f:
                    f.write(recipe.content)

                recipe_name = recipe.content.split("\n")[0]
                tree[category].setdefault(item, {})
                tree[category][item][recipe_name] = file_name

                recipes.setdefault(recipe_name, file_name)


for category in tree:
    for item in sorted(tree[category]):
        category_index = os.path.join(category, 'index.md')
        with open(category_index, 'a+') as f:
            f.write(f'[{item}]({item}/index.md)\n\n')
        item_index = os.path.join(category, item, 'index.md')
        for recipe in sorted(tree[category][item]):
            file_name = tree[category][item][recipe]
            with open(item_index, 'a+') as f:
                f.write(f'[{recipe}]({file_name})\n\n')

with open(os.path.join(recipe_directory, 'index.md'), 'w+') as f:
    for recipe in sorted(recipes):
        f.write(f'[{recipe}]({recipes[recipe]})\n\n')


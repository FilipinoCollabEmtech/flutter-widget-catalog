import os
results = []
for root,_,files in os.walk('C:/'):
    for f in files:
        if 'ruta' in f.lower() and ('icon' in f.lower() or f.endswith('.svg')):
            results.append(os.path.join(root,f))
# write to file in repo
with open('C:/Users/Adminator/Documents/SeeRuta/teammate/_iconsearch.txt','w') as fh:
    fh.write('\n'.join(results[:20]))
    fh.write(f'\nTotal found: {len(results)}')
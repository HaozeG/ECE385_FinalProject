# upscale image data that is originally for a 128*128 screen
# 1*1 -> 2*2

new = []

f = open("./original.txt", "r", encoding='utf-8')
s = f.readlines()
for f1 in s:
    line = ""
    for c in f1:
        line += c + c
    new.append(line.strip())
    new.append(line.strip())
f.close()

f = open("./upscaled.txt","w",newline='')
for l in new:
    f.write(l)
    f.write('\n')
f.close()

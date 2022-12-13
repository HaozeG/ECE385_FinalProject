new = []

f = open("./original.txt", "r", encoding='utf-8')
s = f.readlines()
for f1 in s:
    line = ""
    i = 0
    for c in f1:
        line += c
        i += 1
        if (i == 4):
            new.append(line.strip())
            i = 0
            line = ""
f.close()

f = open("./16bit_wide.txt","w",newline='')
for l in new:
    f.write(l)
    f.write('\n')
f.close()

def split(shares, busWidth, numShares):
    ##put zeros between shares for each word to avoid leakage
    shareList = [shares[i:i+int(busWidth/4)] for i in range(0,len(shares),int(busWidth/4))]
    #print(shareList)
    tmp = []
    #print(shares)
    for i in range(0, len(shareList)):
        tmp.append(shareList[i])
        if (i+1)%numShares != 0:
            tmp.append("0" * int(busWidth/4))
        
    return "".join(tmp)

def splitFile(fileName, busWidth, numShares):

    inFile = open(fileName, 'r')

    outFile = open("split_" + fileName , 'w')

    lines = inFile.readlines()
    inFile.close()
    print(lines)
    for line in lines:        
        if("INS" in line):
            data = line.split("=")[-1].strip(" \n")
            data = split(data, busWidth, numShares)
            outFile.write("INS = " + data + "\n")
        elif ("HDR" in line):
            data = line.split("=")[-1].strip(" \n")
            data = split(data, busWidth, numShares)
            outFile.write("HDR = " + data + "\n")
        elif ("DAT" in line):
            data = line.split("=")[-1].strip(" \n")
            data = split(data, busWidth, numShares)
            #print(data)
            outFile.write("DAT = " + data + "\n")
        else:
            outFile.write(line)

    outFile.close()


def main():  
    BUS_WIDTH = 32
    NUM_SHARES = 2

    PDI_FILE = 'sharedPDI.txt'
    SDI_FILE = 'sharedSDI.txt'

    splitFile(PDI_FILE, BUS_WIDTH, NUM_SHARES)
    splitFile(SDI_FILE, BUS_WIDTH, NUM_SHARES)
    
main()

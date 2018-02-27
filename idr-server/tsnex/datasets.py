from sklearn import datasets
from sklearn.metrics.pairwise import pairwise_distances
from sklearn.utils import shuffle
import numpy as np
import pickle


def load_dataset(name='MNIST-SMALL'):
    print("input dataset name = ", name)
    return {
        'COIL20': load_coil20,
        'MNIST': load_mnist_full,
        'MNIST-SMALL': load_mnist_mini,
        'WIKI-FR': load_wiki,
    }[name]()


def load_coil20():
    import scipy.io
    mat = scipy.io.loadmat("../data/COIL20.mat")
    X, y = mat['X'], mat['Y'][:, 0]
    X, y = shuffle(X, y, n_samples=len(y), random_state=0)
    labels = list(map(str, y.tolist()))
    return X, y, labels


def load_mnist_mini():
    dataset = datasets.load_digits()
    X, y = dataset.data, dataset.target
    labels = list(map(str, y.tolist()))
    return X, y, labels


def load_mnist_full(n_samples=2000):
    from sklearn.datasets import fetch_mldata
    dataset = fetch_mldata('MNIST original', data_home='../data/')
    X, y = dataset.data, dataset.target
    X, y = shuffle(X, y, n_samples=n_samples, random_state=0)
    y = y.astype(int)
    labels = list(map(str, y.tolist()))
    return X, y, labels


def load_wiki(wiki_name='wiki_fr_n3000_d300'):
    print("WIKI-FR")
    inputName = '../data/{}.pickle'.format(wiki_name)
    dataset = pickle.load(open(inputName, 'rb'))
    X, labels = dataset['data'], dataset['labels']
    y = np.zeros(X.shape[0])
    return X, y, labels


def calculate_distances(X, k=100):
    distances = pairwise_distances(X, squared=True)
    neighbors = np.argsort(dist, axis=1)[:, 1:k + 1]
    return {'distances': distances.tolist(), 'neighbors': neighbors.tolist()}


def read_bytes_file(inputName):
    inputName = "../data/iris_tensors.bytes"
    import numpy as np
    import struct
    with open(inputName, 'rb') as f:
        print(struct.unpack('f', f.read(4)))


def top_words(outName, k):   
    n, d = map(int, input().split(' '))
    data = []
    labels = []
    for i in range(k):
        word, *vec = input().split(' ')[:-1]
        vec = list(map(float, vec))
        labels.append(word)
        data.append(vec)
    pickle.dump({'data':np.array(data), 'labels': labels}, open(outName, 'wb'))


if __name__ == '__main__':
    inputBytesFile = "../data/iris_tensors.bytes"
    # read_bytes_file(inputBytesFile)

    # # run command: cat '/home/vmvu/Dataset/FastText/wiki.fr.vec' | python datasets.py 
    k=3000
    outputVecFile = '../data/wiki_fr_n{}_d300.pickle'.format(k)
    # top_words(outputVecFile, k=3000)

    wiki_name = 'wiki_fr_n{}_d300'.format(k)
    data, y, labels = load_wiki(wiki_name)
    print(data.shape, y.shape, len(labels))
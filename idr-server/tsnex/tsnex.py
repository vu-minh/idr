# tsnex.py
# interactive tsne:
# https://www.oreilly.com/learning/an-illustrated-introduction-to-the-t-sne-algorithm

import sklearn
from sklearn.manifold import TSNE
from sklearn.manifold.t_sne import trustworthiness
from sklearn.metrics.pairwise import pairwise_distances
import numpy as np
from numpy import linalg
from time import time, sleep
import json
import utils

import matplotlib.pyplot as plt

shared_interaction = {'queue': None}


def boostrap_do_embedding(X, shared_queue=None):
    """
    Boostrap to start doing embedding:
    Initialize the tsne object, setup params
    """
    print("[TSNEX] Thread to do embedding is starting ... ")

    shared_interaction['queue'] = shared_queue

    sklearn.manifold.t_sne._gradient_descent = my_gradient_descent
    tsne = TSNE(
        n_components=2,
        random_state=0,
        n_iter_without_progress=400,
        verbose=1
    )
    tsne._EXPLORATION_N_ITER = 250
    tsne.init = 'random'

    X_projected = tsne.fit_transform(X)
    return X_projected


# Folk this internal function in
# /opt/anaconda3/lib/python3.6/site-packages/sklearn/manifold/t_sne.py
def my_gradient_descent(objective, p0, it, n_iter,
                        n_iter_check=1, n_iter_without_progress=300,
                        momentum=0.8, learning_rate=200.0, min_gain=0.01,
                        min_grad_norm=1e-7, verbose=0, args=None, kwargs=None):
    """Batch gradient descent with momentum and individual gains.

        Parameters
        ----------
        objective : function or callable
            Should return a tuple of cost and gradient for a given parameter
            vector. When expensive to compute, the cost can optionally
            be None and can be computed every n_iter_check steps using
            the objective_error function.

        p0 : array-like, shape (n_params,)
            Initial parameter vector.

        it : int
            Current number of iterations (this function will be called more than
            once during the optimization).

        n_iter : int
            Maximum number of gradient descent iterations.

        n_iter_check : int
            Number of iterations before evaluating the global error. If the error
            is sufficiently low, we abort the optimization.

        n_iter_without_progress : int, optional (default: 300)
            Maximum number of iterations without progress before we abort the
            optimization.

        momentum : float, within (0.0, 1.0), optional (default: 0.8)
            The momentum generates a weight for previous gradients that decays
            exponentially.

        learning_rate : float, optional (default: 200.0)
            The learning rate for t-SNE is usually in the range [10.0, 1000.0]. If
            the learning rate is too high, the data may look like a 'ball' with any
            point approximately equidistant from its nearest neighbours. If the
            learning rate is too low, most points may look compressed in a dense
            cloud with few outliers.

        min_gain : float, optional (default: 0.01)
            Minimum individual gain for each parameter.

        min_grad_norm : float, optional (default: 1e-7)
            If the gradient norm is below this threshold, the optimization will
            be aborted.

        verbose : int, optional (default: 0)
            Verbosity level.

        args : sequence
            Arguments to pass to objective function.

        kwargs : dict
            Keyword arguments to pass to objective function.

        Returns
        -------
        p : array, shape (n_params,)
            Optimum parameters.

        error : float
            Optimum.

        i : int
            Last iteration.
    """

    if args is None:
        args = []
    if kwargs is None:
        kwargs = {}

    p = p0.copy().ravel()
    update = np.zeros_like(p)
    gains = np.ones_like(p)
    error = np.finfo(np.float).max
    best_error = np.finfo(np.float).max
    best_iter = i = it

    tic = time()

    shared_queue = shared_interaction['queue']
    fixed_ids = []
    fixed_pos = []
    errors = []
    grad_norms = []
    trustworthinesses = []
    stabilities = []
    convergences = []

    X_original = utils.get_X()
    dist_X_original = pairwise_distances(X_original, squared=True)

    print("\nGradien Descent:")
    # for i in range(it, n_iter):
    while True:
        i += 1
        if n_iter < 500 and i > n_iter:  # early_exaggeration
            break

        status = utils.get_server_status(['n_jump', 'tick_frequence', 'stop'])
        if True == status['stop']:
            return p, error, i

        # wait for the `ready` flag to become `True` in order to continue
        # note that, this flag can be changed at any time
        # so for consitently checking this flag, get it directly from redis.
        while False == utils.get_ready_status():
            sleep(status['tick_frequence'])

        # get newest moved points from client
        if not shared_queue.empty():
            shared_item = shared_queue.get()
            fixed_ids = shared_item['fixed_ids']
            fixed_pos = shared_item['fixed_pos']

        # set the fixed points
        if fixed_ids and fixed_pos:
            p2d = p.reshape(-1, 2)
            p2d[fixed_ids] = fixed_pos
            p = p2d.ravel()

        error, grad = objective(p, *args, **kwargs)
        if fixed_ids:
            grad2d = grad.reshape(-1, 2)
            grad2d[fixed_ids] = 0
            grad = grad2d.ravel()

        grad_norm = linalg.norm(grad)

        inc = update * grad < 0.0
        dec = np.invert(inc)
        gains[inc] += 0.2
        gains[dec] *= 0.8
        np.clip(gains, min_gain, np.inf, out=gains)
        grad *= gains
        update = momentum * update - learning_rate * grad
        old_p = p.copy()
        p += update

        if (i % status['n_jump'] == 0):
            X_embedded = p.copy().reshape(-1, 2)
            measure = trustworthiness(
                dist_X_original, X_embedded, n_neighbors=10, precomputed=True)

            trustworthinesses.append(measure)
            errors.append(error)
            grad_norms.append(float(grad_norm))

            stability, convergence = PIVE_measure(old_p, p, dist_X_original)
            stabilities.append(stability)
            convergences.append(convergence)

            publish(p.copy(), errors, trustworthinesses,
                    stabilities, convergences)
            utils.print_progress(i, n_iter)

            # pause, while the other thread sends the published data to client
            # sleep(status['tick_frequence'])

        if (i + 1) % n_iter_check == 0:
            toc = time()
            duration = toc - tic
            tic = toc

            if verbose >= 2:
                print("[t-SNE] Iteration %d: error = %.7f,"
                      " gradient norm = %.7f"
                      " (%s iterations in %0.3fs)"
                      % (i + 1, error, grad_norm, n_iter_check, duration))

            if error < best_error:
                best_error = error
                best_iter = i
            elif i - best_iter > n_iter_without_progress:
                if verbose >= 2:
                    print("[t-SNE] Iteration %d: did not make any progress "
                          "during the last %d episodes. Finished."
                          % (i + 1, n_iter_without_progress))
                break
            if grad_norm <= min_grad_norm:
                if verbose >= 2:
                    print("[t-SNE] Iteration %d: gradient norm %f. Finished."
                          % (i + 1, grad_norm))
                # break

    return p, error, i


def publish(X_embedded, errors, trustworthinesses, stabilities, convergences):
    data = {
        # np.tostring() convert a ndarray to a binary string (bytes)
        # to transfer the data via redis queue,
        # it should convert the bytes to string by decoding them
        # the correct coding schema is latin-1, not utf-8
        'embedding': X_embedded.ravel().tostring().decode('latin-1'),
        'seriesData': [
            {'name': 'errors',
             'series': [errors]},
            {'name': 'trustworthinesses',
             'series': [trustworthinesses]},
            {'name': 'PIVEMeasures',
             'series': [stabilities, convergences]}
        ]
    }
    utils.publish_data(data)


def PIVE_measure(old_p, new_p, dist_X, k=10):
    """ Calculate the measurement in PIVE framework [1]

    stability_{t} = 1/(nk) * \sum^{n}_{i} { | 
        N_k(y_i^{t}) - N_k(y_i^{t-1})
    | }

    convergence_{t} = 1/(nk) * \sum^{n}_{i} { | 
        N_k(y_i^{t}) \intersection N_k(X_i)
    | }

    in which N_k(.) is a set of k nearest neighbors
    and | setA | is the number of elements in setA

    [1] PIVE: Per-Iteration Visualization Environment for Real-Time Interactions
        with Dimension Reduction and Clustering.
    """
    n = dist_X.shape[0]

    dist_old = pairwise_distances(old_p.reshape(-1, 2), squared=True)
    dist_new = pairwise_distances(new_p.reshape(-1, 2), squared=True)

    k_ind_old = np.argsort(dist_old, axis=1)[:, 1:k+1]
    k_ind_new = np.argsort(dist_new, axis=1)[:, 1:k+1]
    k_ind_X = np.argsort(dist_X, axis=1)[:, 1:k+1]

    stability = 0
    for i in range(n):
        set_old = set(k_ind_old[i])
        set_new = set(k_ind_new[i])
        n_new_but_not_old = set_new - set_old
        stability += len(n_new_but_not_old)
    stability /= (n * k)

    convergence = 0
    for i in range(n):
        set_embedded = set(k_ind_new[i])
        set_X = set(k_ind_X[i])
        intersection = set_embedded & set_X
        convergence += len(intersection)
    convergence /= (n * k)

    return stability, convergence


if __name__ == '__main__':
    X, y = utils.load_dataset(name='MNIST')
    tsne = TSNE(
        n_components=2,
        random_state=0,
        init='random',
        n_iter_without_progress=500,
        n_iter=1000,
        verbose=1
    )
    X_2d = tsne.fit_transform(X)
    target_ids = range(len(y))

    plt.figure(figsize=(6, 5))
    colors = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
              "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf"]
    for i, c, label in zip(target_ids, colors, y):
        plt.scatter(X_2d[y == i, 0], X_2d[y == i, 1], c=c, label=label)
    plt.legend()
    plt.show()

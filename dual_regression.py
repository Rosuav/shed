# Can you do two linear regressions at once to do pixel-to-pixel mappings?
############ From Ahmed Hafdi
import numpy as np

def find_affine_transformation(src_points, dst_points):
    """
    Find the affine transformation matrix and translation vector.
   
    src_points: np.array of shape (n, 2) with source points (x, y).
    dst_points: np.array of shape (n, 2) with destination points (x', y').
   
    Returns: affine_matrix of shape (2, 2) and translation vector of shape (2,).
    """
    n = src_points.shape[0]
    A = np.zeros((2 * n, 4))
    B = np.zeros((2 * n))
   
    for i in range(n):
        A[2 * i] = [src_points[i, 0], src_points[i, 1], 1, 0]
        A[2 * i + 1] = [src_points[i, 1], -src_points[i, 0], 0, 1]
        B[2 * i] = dst_points[i, 0]
        B[2 * i + 1] = dst_points[i, 1]
   
    # Solve for the affine transformation parameters
    affine_params, _, _, _ = np.linalg.lstsq(A, B, rcond=None)
    print(affine_params)

    affine_matrix = affine_params[:2].reshape((2, 2))
    translation_vector = affine_params[2:]
   
    return affine_matrix, translation_vector

source_points = [[x, y] for y in range(1, 6) for x in range(1, 6)]

def xfrm(x, y):
	return [2*x + 5, 3*y + x/10]
src_points = np.array(source_points)
dst_points = np.array([xfrm(x, y) for x, y in source_points])

affine_matrix, translation_vector = find_affine_transformation(src_points, dst_points)
print("Affine Matrix:\n", affine_matrix)
print("Translation Vector:\n", translation_vector)

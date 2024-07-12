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
    A = np.zeros((2 * n, 6))
    B = np.zeros((2 * n))
    
    for i in range(n):
        A[2 * i] = [src_points[i, 0], src_points[i, 1], 1, 0, 0, 0]
        A[2 * i + 1] = [0, 0, 0, src_points[i, 0], src_points[i, 1], 1]
        B[2 * i] = dst_points[i, 0]
        B[2 * i + 1] = dst_points[i, 1]
    
    # Solve for the affine transformation parameters
    affine_params, _, _, _ = np.linalg.lstsq(A, B, rcond=None)
    
    return affine_params.reshape((2, 3))

# Example usage
source_points = [[x, y] for y in range(1, 6) for x in range(1, 6)]
def xfrm(x, y):
    return [2*x + 0*y + 5, x/10 + 3*y + 0]

src_points = np.array(source_points)
dst_points = np.array([xfrm(x, y) for x, y in source_points])

affine_matrix = find_affine_transformation(src_points, dst_points)
print("Affine Matrix:\n", affine_matrix)


transformed_points = np.dot([2.5, 2.5, 1], affine_matrix.T)
print("Transformed Points:\n", transformed_points)
print(xfrm(2.5, 2.5))
#print("Destination Points:\n", dst_points)
#print("Difference:\n", transformed_points - dst_points)

print(dst_points)

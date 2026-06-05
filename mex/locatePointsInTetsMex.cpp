#include "mex.h"

#include <algorithm>
#include <cmath>
#include <limits>

namespace {

double valueAt(const double* data, mwSize rowCount, mwIndex row, mwIndex column)
{
    return data[row + column * rowCount];
}

bool isInsideBox(const double point[3], const double boxMin[3], const double boxMax[3])
{
    return point[0] >= boxMin[0] && point[0] <= boxMax[0] &&
           point[1] >= boxMin[1] && point[1] <= boxMax[1] &&
           point[2] >= boxMin[2] && point[2] <= boxMax[2];
}

double determinant3(const double matrix[3][3])
{
    return matrix[0][0] * (matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1]) -
           matrix[0][1] * (matrix[1][0] * matrix[2][2] - matrix[1][2] * matrix[2][0]) +
           matrix[0][2] * (matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0]);
}

bool solve3x3(const double matrix[3][3], const double rhs[3], double solution[3])
{
    const double detA = determinant3(matrix);
    if (std::abs(detA) < std::numeric_limits<double>::epsilon()) {
        return false;
    }

    double temp[3][3];
    for (mwIndex column = 0; column < 3; ++column) {
        for (mwIndex r = 0; r < 3; ++r) {
            for (mwIndex c = 0; c < 3; ++c) {
                temp[r][c] = (c == column) ? rhs[r] : matrix[r][c];
            }
        }
        solution[column] = determinant3(temp) / detA;
    }
    return true;
}

} // namespace

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[])
{
    if (nrhs != 4) {
        mexErrMsgIdAndTxt("locatePointsInTetsMex:BadInputCount",
            "Expected nodes, elements, points, and tolerance.");
    }
    if (nlhs > 1) {
        mexErrMsgIdAndTxt("locatePointsInTetsMex:BadOutputCount",
            "Only one output is supported.");
    }
    for (int input = 0; input < 3; ++input) {
        if (!mxIsDouble(prhs[input]) || mxIsComplex(prhs[input])) {
            mexErrMsgIdAndTxt("locatePointsInTetsMex:BadInputType",
                "nodes, elements, and points must be real double arrays.");
        }
    }
    if (!mxIsDouble(prhs[3]) || mxIsComplex(prhs[3]) ||
            mxGetNumberOfElements(prhs[3]) != 1) {
        mexErrMsgIdAndTxt("locatePointsInTetsMex:BadTolerance",
            "tolerance must be a real double scalar.");
    }

    const mwSize nodeCount = mxGetM(prhs[0]);
    const mwSize nodeColumns = mxGetN(prhs[0]);
    const mwSize elementCount = mxGetM(prhs[1]);
    const mwSize elementColumns = mxGetN(prhs[1]);
    const mwSize pointCount = mxGetM(prhs[2]);
    const mwSize pointColumns = mxGetN(prhs[2]);
    if (nodeColumns != 3 || elementColumns != 4 || pointColumns != 3) {
        mexErrMsgIdAndTxt("locatePointsInTetsMex:BadDimensions",
            "nodes must be N-by-3, elements M-by-4, and points P-by-3.");
    }

    const double* nodes = mxGetPr(prhs[0]);
    const double* elements = mxGetPr(prhs[1]);
    const double* points = mxGetPr(prhs[2]);
    const double tolerance = mxGetScalar(prhs[3]);

    plhs[0] = mxCreateDoubleMatrix(pointCount, 1, mxREAL);
    double* output = mxGetPr(plhs[0]);
    const double nanValue = mxGetNaN();
    std::fill(output, output + pointCount, nanValue);

    if (pointCount == 0 || elementCount == 0 || nodeCount == 0) {
        return;
    }

    double globalMin[3] = {std::numeric_limits<double>::infinity(),
                           std::numeric_limits<double>::infinity(),
                           std::numeric_limits<double>::infinity()};
    double globalMax[3] = {-std::numeric_limits<double>::infinity(),
                           -std::numeric_limits<double>::infinity(),
                           -std::numeric_limits<double>::infinity()};
    for (mwIndex node = 0; node < nodeCount; ++node) {
        for (mwIndex dim = 0; dim < 3; ++dim) {
            const double value = valueAt(nodes, nodeCount, node, dim);
            globalMin[dim] = std::min(globalMin[dim], value - tolerance);
            globalMax[dim] = std::max(globalMax[dim], value + tolerance);
        }
    }

    for (mwIndex pointIndex = 0; pointIndex < pointCount; ++pointIndex) {
        const double point[3] = {
            valueAt(points, pointCount, pointIndex, 0),
            valueAt(points, pointCount, pointIndex, 1),
            valueAt(points, pointCount, pointIndex, 2)};

        if (!isInsideBox(point, globalMin, globalMax)) {
            continue;
        }

        for (mwIndex elementIndex = 0; elementIndex < elementCount; ++elementIndex) {
            mwIndex nodeIds[4];
            bool validElement = true;
            for (mwIndex localNode = 0; localNode < 4; ++localNode) {
                const double nodeId = valueAt(elements, elementCount, elementIndex, localNode);
                if (nodeId < 1.0 || nodeId > static_cast<double>(nodeCount)) {
                    validElement = false;
                    break;
                }
                nodeIds[localNode] = static_cast<mwIndex>(nodeId) - 1;
            }
            if (!validElement) {
                continue;
            }

            double vertices[4][3];
            double boxMin[3] = {std::numeric_limits<double>::infinity(),
                                std::numeric_limits<double>::infinity(),
                                std::numeric_limits<double>::infinity()};
            double boxMax[3] = {-std::numeric_limits<double>::infinity(),
                                -std::numeric_limits<double>::infinity(),
                                -std::numeric_limits<double>::infinity()};
            for (mwIndex localNode = 0; localNode < 4; ++localNode) {
                for (mwIndex dim = 0; dim < 3; ++dim) {
                    const double value = valueAt(nodes, nodeCount, nodeIds[localNode], dim);
                    vertices[localNode][dim] = value;
                    boxMin[dim] = std::min(boxMin[dim], value - tolerance);
                    boxMax[dim] = std::max(boxMax[dim], value + tolerance);
                }
            }
            if (!isInsideBox(point, boxMin, boxMax)) {
                continue;
            }

            double matrix[3][3];
            double rhs[3];
            for (mwIndex dim = 0; dim < 3; ++dim) {
                matrix[dim][0] = vertices[1][dim] - vertices[0][dim];
                matrix[dim][1] = vertices[2][dim] - vertices[0][dim];
                matrix[dim][2] = vertices[3][dim] - vertices[0][dim];
                rhs[dim] = point[dim] - vertices[0][dim];
            }

            double local[3];
            if (!solve3x3(matrix, rhs, local)) {
                continue;
            }

            const double bary0 = 1.0 - local[0] - local[1] - local[2];
            const bool inside = bary0 >= -tolerance && bary0 <= 1.0 + tolerance &&
                                local[0] >= -tolerance && local[0] <= 1.0 + tolerance &&
                                local[1] >= -tolerance && local[1] <= 1.0 + tolerance &&
                                local[2] >= -tolerance && local[2] <= 1.0 + tolerance;
            if (inside) {
                output[pointIndex] = static_cast<double>(elementIndex + 1);
                break;
            }
        }
    }
}

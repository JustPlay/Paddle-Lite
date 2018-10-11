/* Copyright (c) 2018 PaddlePaddle Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

/*
conv
conv_bn
conv_add
conv_relu
conv_bn_relu
conv_add_relu
conv_add_bn_relu

*/

/*

#include "common.h"

__kernel void conv_1x1(__private const int global_size_dim0,
                       __private const int global_size_dim1,
                       __private const int global_size_dim2,
                       __read_only image2d_t input,
                       __read_only image2d_t filter,
#ifdef BIASE
                       __read_only image2d_t bias,
#endif
#ifdef BATCH_NORM
                       __read_only image2d_t new_scale,
                       __read_only image2d_t new_biase,
#endif
                       __write_only image2d_t output_image,
                       __private const int stride,
                       __private const int offset,
                       __private const int input_c,
                       __private const int input_width,/* of one block */
                       __private const int input_height/* of one block */) {
  const int out_c = get_global_id(0);
  const int out_w = get_global_id(1);
  const int out_nh = get_global_id(2);

  const sampler_t sampler = CLK_NORMALIZED_COORDS_TRUE |
                           CLK_ADDRESS_CLAMP         |
                           CLK_FILTER_NEAREST;
  const uint kernelHXW = 1;
  int2 stride_xy = int2(stride, stride);
  int2 ouput_pos_in_one_block = int2(out_w, out_nh);
  int2 in_pos_in_one_block = ouput_pos_in_one_block * stride_xy + int2(offset, offset);
  int input_c;
#ifdef BIASE
    half4 output = read_imageh(bias, sampler, int2(out_c, 0));
#else
    half4 output = 0.0;
#endif

  for (int i = 0; i < input_c;h ++i) {
    int2 pos_in = int2(i * input_width + in_pos_in_one_block.x, in_pos_in_one_block.y);
    if (pos_in.x >=0 && pos_in.y >= 0 && pos_in.x < input_width && pos_in.y < input_height) {
        hafl4 input = read_imageh(input, sampler, pos_in);

        half4 weight_x = read_imageh(filter, sampler, int2(i, out_c * 4 + 0));
        output.x += dot(input, weight_x);

        half4 weight_y = read_imageh(filter, sampler, int2(i, out_c * 4 + 1));
        output.y += dot(input, weight_y);

        half4 weight_z = read_imageh(filter, sampler, int2(i, out_c * 4 + 2));
        output.z += dot(input, weight_z);

        half4 weight_w = read_imageh(filter, sampler, int2(i, out_c * 4 + 3));
        output.w += dot(input, weight_w);
    }
  }

#ifdef BATCH_NORM
    output = output * read_imageh(new_scale, sampler, int2(out_c, 0)) + read_imageh(new_biase, sampler, int2(out_c, 0))
#endif

#ifdef RELU
  output = activation(output);
#endif

  int2 output_pos(out_c * global_size_dim1 + out_w, out_nh);
  write_imageh(output_image, output_pos, output);
}


__kernel void conv_3x3(__private const int global_size_dim0,
                                              __private const int global_size_dim1,
                                              __private const int global_size_dim2,
                                              __read_only image2d_t input,
                                              __read_only image2d_t filter,
#ifdef BIASE
                                              __read_only image2d_t bias,
#endif

#ifdef BATCH_NORM
                                              __read_only image2d_t new_scale,
                                              __read_only image2d_t new_biase,
#endif
                                              __write_only image2d_t output_image,
                                              __private const int stride,
                                              __private const int offset,
                                              __private const int input_c,
                                              __private const int dilation,
                                              __private const int input_width,/* of one block */
                                              __private const int input_height/* of one block */) {
    int2 stride_xy = int2(stride, stride);
    int2 ouput_pos_in_one_block = int2(out_w, out_nh);
    int2 in_pos_in_one_block = ouput_pos_in_one_block * stride_xy + int2(offset, offset);

#ifdef BIASE
    half4 output = read_imageh(bias, sampler, int2(out_c, 0));
#else
    half4 output = 0.0;
#endif

    half4 input[9];

    for (int i = 0; i < input_c; ++i) {
        int2 pos_in = int2(i * input_width + in_pos_in_one_block.x, in_pos_in_one_block.y);

        input[0] = select(read_imageh(input, sampler,
                          int2(pos_in.x - dilation, pos_in.y - dilation)),
                          half4(0.0),in_pos_in_one_block.x - dilation < 0 || in_pos_in_one_block.y - dilation < 0 || in_pos_in_one_block.x - dilation >= input_width || in_pos_in_one_block.y - dilation >= input_height);

        input[1] = select(read_imageh(input, sampler,
                          int2(pos_in.x, pos_in.y - dilation)),
                          half4(0.0),in_pos_in_one_block.x < 0 || in_pos_in_one_block.y - dilation < 0 || in_pos_in_one_block.x >= input_width || in_pos_in_one_block.y - dilation >= input_height);

        input[2] = select(read_imageh(input, sampler,
                          int2(pos_in.x + dilation, pos_in.y - dilation)),
                          half4(0.0),in_pos_in_one_block.x + dilation < 0 || in_pos_in_one_block.y - dilation < 0 || in_pos_in_one_block.x + dilation >= input_width || in_pos_in_one_block.y - dilation >= input_height);

        input[3] = select(read_imageh(input, sampler,
                          int2(pos_in.x - dilation, pos_in.y)),
                          half4(0.0), in_pos_in_one_block.x - dilation < 0 || in_pos_in_one_block.y < 0 || in_pos_in_one_block.x - dilation >= input_width || in_pos_in_one_block.y >= input_height);

        input[4] = select(read_imageh(input, sampler,
                          int2(pos_in.x, pos_in.y)),
                          half4(0.0), in_pos_in_one_block.x < 0 || in_pos_in_one_block.y < 0 || in_pos_in_one_block.x >= input_width || in_pos_in_one_block.y >= input_height);

        input[5] = select(read_imageh(input, sampler,
                          int2(pos_in.x + dilation, pos_in.y)),
                          half4(0.0), in_pos_in_one_block.x + dilation < 0 || in_pos_in_one_block.y < 0 || in_pos_in_one_block.x + dilation >= input_width || in_pos_in_one_block.y >= input_height);

        input[6] = select(read_imageh(input, sampler,
                          int2(pos_in.x - dilation, pos_in.y + dilation)),
                          half4(0.0), in_pos_in_one_block.x - dilation < 0 || in_pos_in_one_block.y + dilation < 0 || in_pos_in_one_block.x - dilation >= input_width || in_pos_in_one_block.y + dilation >= input_height);

        input[7] = select(read_imageh(input, sampler,
                          int2(pos_in.x, pos_in.y + dilation)),
                          half4(0.0), in_pos_in_one_block.x < 0 || in_pos_in_one_block.y + dilation < 0 || in_pos_in_one_block.x >= input_width || in_pos_in_one_block.y + dilation >= input_height);

        input[8] = select(read_imageh(input, sampler,
                          int2(pos_in.x + dilation, pos_in.y + dilation)),
                          half4(0.0), pos_in.x + dilation < 0 || in_pos_in_one_block.y + dilation < 0 || pos_in.x + dilation >= input_width || in_pos_in_one_block.y + dilation >= input_height);


        for (int j = 0; j < 9; ++j) {

            half4 weight_x = read_imageh(filter, sampler, int2(i * 3 + j % 3, out_c * 4 * 3 + 0 * out_c * 3 + j / 3));
            output.x += dot(input[j], weight_x);

            half4 weight_y = read_imageh(filter, sampler, int2(i * 3 + j % 3, out_c * 4 * 3 + 1 * out_c * 3 + j / 3));
            output.y += dot(input[j], weight_y);

            half4 weight_z = read_imageh(filter, sampler, int2(i * 3 + j % 3, out_c * 4 * 3 + 2 * out_c * 3 + j / 3));
            output.z += dot(input[j], weight_z);

            half4 weight_w = read_imageh(filter, sampler, int2(i * 3 + j % 3, out_c * 4 * 3 + 3 * out_c * 3 + j / 3));
            output.w += dot(input[j], weight_w);

        }
    }

#ifdef BATCH_NORM
    output = output * read_imageh(new_scale, sampler, int2(out_c, 0)) + read_imageh(new_biase, sampler, int2(out_c, 0))
#endif

#ifdef RELU
    output = activation(output);
#endif

    int2 output_pos(out_c * global_size_dim1 + out_w, out_nh);
    write_imageh(output_image, output_pos, output);
}



__kernel void depth_conv_3x3(__private const int global_size_dim0,
                                              __private const int global_size_dim1,
                                              __private const int global_size_dim2,
                                              __read_only image2d_t input,
                                              __read_only image2d_t filter,
#ifdef BIASE
                                              __read_only image2d_t bias,
#endif
#ifdef BATCH_NORM
                                              __read_only image2d_t new_scale,
                                              __read_only image2d_t new_biase,
#endif
                                              __write_only image2d_t output_image,
                                              __private const int stride,
                                              __private const int offset,
                                              __private const int input_c,
                                              __private const int dilation,
                                              __private const int input_width,/* of one block */
                                              __private const int input_height, /* of one block */
                                              __private const int output_width,
                                              __private const int output_height) {

    const int out_c = get_global_id(0);
    const int out_w = get_global_id(1);
    const int out_nh = get_global_id(2);

    const sampler_t sampler = CLK_NORMALIZED_COORDS_TRUE |
                              CLK_ADDRESS_CLAMP          |
                              CLK_FILTER_NEAREST;

    const int batch_index = out_nh / output_height;

    const int out_nh_in_one_batch = out_nh % output_height;

    const uint kernelHXW = 1;

    int2 stride_xy = int2(stride, stride);
    int2 ouput_pos_in_one_block = int2(out_w, out_nh_in_one_batch);

    int2 in_pos_in_one_block = ouput_pos_in_one_block * stride_xy + int2(offset, offset);

#ifdef BIASE
    half4 output = read_imageh(bias, sampler, int2(out_c, 0));
#else
    half4 output = 0.0;
#endif

    int2 pos_in_input_block = int2(out_c * input_width, batch_index * input_height);

    int weight_x_to = out_c * 3;

    half4 inputs[9];

    inputs[0] = select(read_imageh(input, sampler, int2(pos_in_input_block.x + in_pos_in_one_block.x - 1, pos_in_input_block.y + in_pos_in_one_block.y - 1)),
                       0.0,
                       in_pos_in_one_block.x - 1 < 0 || in_pos_in_one_block.y - 1 < 0 || in_pos_in_one_block.x - 1 >= input_width || in_pos_in_one_block.y - 1 >= input_height);

    inputs[1] = select(read_imageh(input, sampler, int2(pos_in_input_block.x + in_pos_in_one_block.x, pos_in_input_block.y + in_pos_in_one_block.y - 1)),
                       0.0,
                       n_pos_in_one_block.x < 0 || in_pos_in_one_block.y - 1 < 0 || in_pos_in_one_block.x >= input_width || in_pos_in_one_block.y - 1 >= input_height);

    inputs[2] = select(read_imageh(input, sampler, int2(pos_in_input_block.x + in_pos_in_one_block.x + 1, pos_in_input_block.y + in_pos_in_one_block.y - 1)),
                       0.0,
                       in_pos_in_one_block.x + 1 < 0 || in_pos_in_one_block.y - 1 < 0 || in_pos_in_one_block.x + 1 >= input_width || in_pos_in_one_block.y - 1 >= input_height);
    inputs[3] = select(read_imageh(input, sampler, int2(pos_in_input_block.x + in_pos_in_one_block.x - 1, pos_in_input_block.y + in_pos_in_one_block.y)),
                       0.0,
                       in_pos_in_one_block.x - 1 < 0 || in_pos_in_one_block.y < 0 || in_pos_in_one_block.x - 1 >= input_width || in_pos_in_one_block.y >= input_height);
    inputs[4] = select(read_imageh(input, sampler, int2(pos_in_input_block.x + in_pos_in_one_block.x, pos_in_input_block.y + in_pos_in_one_block.y)),
                       0.0,
                       in_pos_in_one_block.x < 0 || in_pos_in_one_block.y < 0 || in_pos_in_one_block.x >= input_width || in_pos_in_one_block.y >= input_height);

    inputs[5] = select(read_imageh(input, sampler, int2(pos_in_input_block.x + in_pos_in_one_block.x + 1, pos_in_input_block.y + in_pos_in_one_block.y)),
                       0.0,
                       in_pos_in_one_block.x + 1 < 0 || in_pos_in_one_block.y < 0 || in_pos_in_one_block.x + 1 >= input_width || in_pos_in_one_block.y >= input_height);

    inputs[6] = select(read_imageh(input, sampler, int2(pos_in_input_block.x + in_pos_in_one_block.x - 1, pos_in_input_block.y + in_pos_in_one_block.y + 1)),
                       0.0,
                       in_pos_in_one_block.x - 1 < 0 || in_pos_in_one_block.y + 1 < 0 || in_pos_in_one_block.x - 1 >= input_width || in_pos_in_one_block.y + 1 >= input_height);

    inputs[7] = select(read_imageh(input, sampler, int2(pos_in_input_block.x + in_pos_in_one_block.x, pos_in_input_block.y + in_pos_in_one_block.y + 1)),
                       0.0,
                       in_pos_in_one_block.x < 0 || in_pos_in_one_block.y + 1 < 0 || in_pos_in_one_block.x >= input_width || in_pos_in_one_block.y + 1 >= input_height);

    inputs[8] = select(read_imageh(input, sampler, int2(pos_in_input_block.x + in_pos_in_one_block.x + 1, pos_in_input_block.y + in_pos_in_one_block.y + 1)),
                       0.0,
                       in_pos_in_one_block.x + 1 < 0 || in_pos_in_one_block.y + 1 < 0 || in_pos_in_one_block.x + 1 >= input_width || in_pos_in_one_block.y + 1 >= input_height);

    for (int j = 0; j < 9; ++j) {
        half4 input = inputs[j];
        half4 weight = read_imageh(filter, sampler, int2(weight_x_to + j % 3, j / 3));
        output.x += input.x * weight.x;
        output.y += input.y * weight.y;
        output.z += input.z * weight.z;
        output.w += input.w * weight.w;
    }

#ifdef BATCH_NORM
    output = output * read_imageh(new_scale, sampler, int2(out_c, 0)) + read_imageh(new_biase, sampler, int2(out_c, 0))
#endif

#ifdef RELU
    output = activation(output);
#endif

    int2 output_pos(out_c * global_size_dim1 + out_w, out_nh);
    write_imageh(output_image, output_pos, output);
}

*/
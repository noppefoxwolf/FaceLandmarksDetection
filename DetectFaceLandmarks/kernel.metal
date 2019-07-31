//
//  kernel.metal
//  Example
//
//  Created by Tomoya Hirano on 2019/07/13.
//  Copyright © 2019 Tomoya Hirano. All rights reserved.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
#include <metal_common>
#include <simd/simd.h>

using namespace metal;

extern "C" {
  namespace coreimage {
    //https://lensstudio.snapchat.com/templates/face/distort/
    //https://ccrma.stanford.edu/~jacobliu/368Report/index.html
    
    // x どのXか
    // m 膨らむ箇所
    // s ながらかさ
    // ガウス関数
    float gauss(float x, float m, float s) {
      return exp( -pow(x - m, 2) / (2 * pow(s, 2)));
    }
    
    //右
    float2 warp(float a0, float a1, destination dest) {
      float2 location = dest.coord(); //現在の場所
      float mu = (location.y - a0) / a1; //x軸上にある特徴点の場所
      float s = 10; //顔の大きさと傾きを係数にかけたい
      float g = gauss(location.x, mu, s);
      return location;
//      if (g == 0) {
//        return location;
//      } else {
//        return float2(0,0);
//      }
//
//
      if (location.x < mu) {
        // 0.0 ~ 1.0
        return location;
      } else {
        // 1.0 ~ 0.0
        return float2(0, location.y - (g * g * s));
      }
    }
  }
}

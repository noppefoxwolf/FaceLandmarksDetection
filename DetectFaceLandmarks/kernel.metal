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
    // https://lensstudio.snapchat.com/templates/face/distort/
    // https://ccrma.stanford.edu/~jacobliu/368Report/index.html
    // http://hooktail.sub.jp/mathInPhys/fwhmsigma/
    // http://light11.hatenadiary.com/entry/2018/05/17/225508
    // x どのXか
    // m 膨らむ箇所
    // s ながらかさ
    // ガウス関数
    float gauss(float x, float m, float s) {
      return exp( -pow(x - m, 2) / (2 * pow(s, 2)));
    }
    
    //https://mathtrain.jp/quad
    //ラグランジュの補間公式
    float lagrange(float x, float2 a, float2 b, float2 c) {
      return (a.y * ( ((x - b.x) * (x - c.x)) / ((a.x - b.x) * (a.x - c.x)) )) +
             (b.y * ( ((x - a.x) * (x - c.x)) / ((b.x - a.x) * (b.x - c.x)) )) +
             (c.y * ( ((x - a.x) * (x - b.x)) / ((c.x - a.x) * (c.x - b.x)) ));
    }
    
    float linear(float y, float a, float b) { // -> x
      return (y - a) / b;
    }
    
    // http://www.geisya.or.jp/~mwm48961/kou3/quad_eq2.htm
    
    float quadratic(float y, float a, float b, float c) { // -> x
      return (-b + sqrt( pow(b, 2) - (4 * a * (c - y)) )) / (2 * a);
    }
    
    float quadratic_m(float y, float a, float b, float c) { // -> x
      return (-b - sqrt( pow(b, 2) - (4 * a * (c - y)) )) / (2 * a);
    }
    
    float2 quadraticWarp(float a, float b, float c, float w, float h, destination dest) {
      float2 location = dest.coord(); //現在の場所
      float gy = gauss(location.y, h / 2, h / 6);
      return float2(location.x + (10 * gy), location.y);
//
//      // 右
//      float mu = quadratic(location.y, a, b, c); //x軸上にある特徴点の場所
//      float s = w / 100; //顔の大きさと傾きを係数にかけたい
//      float g = gauss(location.x, mu, s);
//      float gy = gauss(location.y, h / 2, h / 2);
//      if (g == 0) {
//        return location;//float2(0,0);
//        // 左
//        float mu2 = quadratic_m(location.y, a, b, c); //x軸上にある特徴点の場所
//        float s2 = 25; //顔の大きさと傾きを係数にかけたい
//        float g2 = gauss(location.x, mu2 + s2, s2);
//        if (g2 == 0) {
//          return location;//float2(0,0);
//        } else {
//          if (mu2 < location.x) {
//            return location;//float2(0,0);
//          } else {
//            return float2(location.x - ((1 - g2) * s2), location.y);
//          }
//        }
//      } else {
//        return float2(location.x + (10 * gy), location.y);
//      }
    }
    // 右
    // 正面向いてないので注意
    float2 linearWarp(float a, float b, destination dest) {
      float2 location = dest.coord(); //現在の場所
      float mu = linear(location.y, a, b); //x軸上にある特徴点の場所
      float s = 25; //顔の大きさと傾きを係数にかけたい
      float g = gauss(location.x, mu + 10, s);
      
      return location;
//      if (location.x > mu) {
//        return float2(location.x + (g * s), location.y);
//      } else {
//        return float2(location.x + (g * s), location.y);
//      }
    }
  }
}

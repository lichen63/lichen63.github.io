---
title: 在Godot中截取Image里的部分图片
description: 记录在Godot中如何截取Image里的部分图片的过程
author: Lichen
date: 2025-01-03 17:30:00 +0800
categories: [游戏, 开发]
tags: [游戏, 开发, Godot]
pin: false
published: true
media_subpath: '/assets/posts/20250103'
---

<style>
    img {
        width: 300px;
        height: 200px;
    }
</style>

## 1. 需求

开发[Spritesheet Tool](https://github.com/lichen63/godot-tools/tree/main/spritesheet-tools)的时候，有个需求是导入一张图片，然后截取这个图片的一部分保存在Image里，然后保存到本地文件，我问了GPT，得到了这个答案：

```gdscript
var sub_image: Image = Image.new()
sub_image.create(cell_width, cell_height, false, viewport_image.get_format())
sub_image.blit_rect(viewport_image, Rect2(Vector2(x, y), Vector2(cell_width, cell_height)), Vector2(0, 0))
var save_path = "%s/cell_%d.png" % [output_dir, index]
sub_image.save_png(save_path)
```

运行后，不出意料的报错了：

```
E 0:00:24:0080   control.gd:374 @ split_and_save_images(): Condition "dsize == 0" is true.
  <C++ Source>   core/io/image.cpp:2772 @ blit_rect()
  <Stack Trace>  control.gd:374 @ split_and_save_images()
                 control.gd:414 @ _on_test_2_pressed()
```

## 2. 分析和解决

看起来是个小错误，我原本以为是`viewport_image`的dsize是0，于是检查了下，没发现什么问题。再仔细看，发现dsize应该指向的是新创建的`sub_image`，于是开始查阅源码 [Image::blit_rect](https://github.com/godotengine/godot/blob/master/core/io/image.cpp#L2863)（顺带说一句：Godot报错时可以右键点击直接跳转到源码报错处，这感觉太棒了），发现`dsize`就是成员变量`data`的size，于是开始研究`data`的赋值函数（再吐槽一下，Godot的C++成员变量竟然不带prefix或suffix下划线，这种代码风格看起来很不适应，查找变量时也容易和本地变量搞混），发现是在 [Image::initialize_data](https://github.com/godotengine/godot/blob/master/core/io/image.cpp#L2208) 时就赋值了，这就有点奇怪了，就是简单的创建一个空的`Image`，不应该初始化都出问题吧。

我怀疑是我的项目其它地方有问题，导致这里被影响到了，于是新建了一个空场景，拖了两个`TextureRect`进来，一个用项目自带的png图片初始化了，另一个没有赋值，然后让GPT写了个简单的脚本（我去掉了一些check逻辑，让代码更简单些）：

```gdscript
extends Control

@onready var texture_src: TextureRect = $TextureRectSrc
@onready var texture_dst: TextureRect = $TextureRectDst

func _ready() -> void:
    var src_texture = texture_src.texture
    var image = src_texture.get_data()
    image.lock()
    var rect = Rect2(50, 50, 100, 100)
    var cropped_image = Image.new()
    cropped_image.create(rect.size.x, rect.size.y, false, image.get_format())
    cropped_image.blit_rect(image, rect, Vector2.ZERO)
    cropped_image.unlock()
    var cropped_texture = ImageTexture.new()
    cropped_texture.create_from_image(cropped_image)
    texture_dst.texture = cropped_texture
```

然后就是运行，报错，发给GPT，修改，最终可以运行了：

```gdscript
func _ready() -> void:
    var src_texture = texture_src.texture
    var image = src_texture.get_data()
    var rect = Rect2(50, 50, 100, 100)
    var cropped_image = Image.new()
    cropped_image.create(rect.size.x, rect.size.y, false, image.get_format())
    cropped_image.blit_rect(image, rect, Vector2.ZERO)
    var cropped_texture = ImageTexture.new()
    cropped_texture.create_from_image(cropped_image)
    texture_dst.texture = cropped_texture
```

但是dsize的报错依然存在，我当时想，这么简单的逻辑，难道Godot真的有问题？于是拉下来Godot的源码，一边build一边在本地看代码，还没build完就发现了一个小问题 [core/io
/image.cpp](https://github.com/godotengine/godot/blob/master/core/io/image.cpp#L3511)：

```cpp
#ifndef DISABLE_DEPRECATED
	ClassDB::bind_static_method("Image", D_METHOD("create", "width", "height", "use_mipmaps", "format"), &Image::create_empty);
#endif
```

`Image`的`create`函数被标记为了`DEPRECATED`，再去 [Godot Doc](https://docs.godotengine.org/en/stable/classes/class_image.html#class-image-method-create) 上一看，果然如此，应该用`create_empty`来替代，虽然两者的实现是一样的，都是`create_empty`，但既然deprecated了，那就改：

```gdscript
func _ready() -> void:
    var src_texture = texture_src.texture
    var image = src_texture.get_data()
    var rect = Rect2(50, 50, 100, 100)
    var cropped_image = Image.new()
    cropped_image.create_empty(rect.size.x, rect.size.y, false, image.get_format())
    cropped_image.blit_rect(image, rect, Vector2.ZERO)
    var cropped_texture = ImageTexture.new()
    cropped_texture.create_from_image(cropped_image)
    texture_dst.texture = cropped_texture
```

改了之后肯定还是报错，因为两者实现其实是一样的，而这时再问GPT，它已经开始胡言乱语了，我只能自己找原因了，好久之后，才在无意中就发现`create_empty`是一个static方法，而我是用了实例来调用。我有点想吐槽，为什么用实例来调用静态方法没有任何build和runtime error……

同时发现`create_from_image`也是静态方法，于是最终版本改成这样：

```gdscript
func _ready() -> void:
    var src_texture = texture_src.texture
    var image = src_texture.get_image()
    var rect = Rect2(5, 5, 50, 50)
    var cropped_image = Image.create_empty(rect.size.x, rect.size.y, false, image.get_format())
    cropped_image.blit_rect(image, rect, Vector2.ZERO)
    var cropped_texture = ImageTexture.create_from_image(cropped_image)
    texture_dst.texture = cropped_texture
```

运行没问题，截出来的图片可以正常显示了，芜湖！

## 3. 吐槽

很显然，这是一个很简单的问题，细心一点的话很快就能解决了，根源就是用了实例去调用了静态方法，但是中间我花了不少的时间去阅读源码，曲曲折折地才发现了问题所在。事后想想，如果当初我不是去让GPT直接帮我写代码，而是自己去官方文档上去查看，可能很早就发现了应该用`create_empty`，而且它还是个static方法，这样可能就会避免这个过程中的一些弯路了。

所以，GPT还是很有用的，只是下次对于一些调用的函数，自己要点进去看看其实现是不是预期的，在这里花些时间可以有效避免后续的踩坑。而Godot的静态方法上面缺少build和runtime error也是给我一个提醒，下次要多加小心。

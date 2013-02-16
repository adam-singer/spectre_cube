import 'dart:html';
import 'dart:math';
import 'package:vector_math/vector_math.dart';
import 'package:game_loop/game_loop.dart';
import 'package:asset_pack/asset_pack.dart';
import 'package:spectre/spectre.dart';
import 'package:spectre/spectre_asset_pack.dart';

final String _canvasId = '#backbuffer';

GraphicsDevice _graphicsDevice;
GraphicsContext _graphicsContext;
DebugDrawManager _debugDrawManager;

GameLoop _gameLoop;
AssetManager _assetManager;

Viewport _viewport;
final Camera camera = new Camera();
final cameraController = new MouseKeyboardCameraController();
double _lastTime;
bool _circleDrawn = false;

/* Skybox */
SingleArrayIndexedMesh _skyboxMesh;
ShaderProgram _skyboxShaderProgram;
InputLayout _skyboxInputLayout;
SamplerState _skyboxSampler;
DepthState _skyboxDepthState;
BlendState _skyboxBlendState;
RasterizerState _skyboxRasterizerState;

Float32Array _cameraTransform = new Float32Array(16);
Float32Array _unitCubeTransform = new Float32Array(16);
double translateX = 0.0, translateY = 0.0, translateZ = -2.0;
void gameFrame(GameLoop gameLoop) {
  double dt = gameLoop.dt;
  cameraController.forwardVelocity = 25.0;
  cameraController.strafeVelocity = 25.0;
  cameraController.forward =
      gameLoop.keyboard.buttons[GameLoopKeyboard.W].down;
  cameraController.backward =
      gameLoop.keyboard.buttons[GameLoopKeyboard.S].down;
  cameraController.strafeLeft =
      gameLoop.keyboard.buttons[GameLoopKeyboard.A].down;
  cameraController.strafeRight =
      gameLoop.keyboard.buttons[GameLoopKeyboard.D].down;
  if (gameLoop.pointerLock.locked) {
    cameraController.accumDX = gameLoop.mouse.dx;
    cameraController.accumDY = gameLoop.mouse.dy;
  }

  if (gameLoop.keyboard.buttons[GameLoopKeyboard.RIGHT].down) {
    translateX+=0.1;
  }

  if (gameLoop.keyboard.buttons[GameLoopKeyboard.LEFT].down) {
    translateX-=0.1;
  }

  if (gameLoop.keyboard.buttons[GameLoopKeyboard.UP].down) {
    translateY+=0.1;
  }

  if (gameLoop.keyboard.buttons[GameLoopKeyboard.DOWN].down) {
    translateY-=0.1;
  }

  if (gameLoop.keyboard.buttons[GameLoopKeyboard.Z].down) {
    translateZ+=0.1;
  }

  if (gameLoop.keyboard.buttons[GameLoopKeyboard.X].down) {
    translateZ-=0.1;
  }

  cameraController.UpdateCamera(gameLoop.dt, camera);
  // Update the debug draw manager state
  _debugDrawManager.update(dt);
}

void renderFrame(GameLoop gameLoop) {
  // Clear the color buffer
  _graphicsContext.clearColorBuffer(0.0, 0.0, 0.0, 1.0);
  // Clear the depth buffer
  _graphicsContext.clearDepthBuffer(1.0);
  // Reset the context
  _graphicsContext.reset();
  // Set the viewport
  _graphicsContext.setViewport(_viewport);
  // Add three lines, one for each axis.
  _debugDrawManager.addLine(new vec3.raw(0.0, 0.0, 0.0),
                            new vec3.raw(10.0, 0.0, 0.0),
                            new vec4.raw(1.0, 0.0, 0.0, 1.0));
  _debugDrawManager.addLine(new vec3.raw(0.0, 0.0, 0.0),
                            new vec3.raw(0.0, 10.0, 0.0),
                            new vec4.raw(0.0, 1.0, 0.0, 1.0));
  _debugDrawManager.addLine(new vec3.raw(0.0, 0.0, 0.0),
                            new vec3.raw(0.0, 0.0, 10.0),
                            new vec4.raw(0.0, 0.0, 1.0, 1.0));
  if (_circleDrawn == false) {
    _circleDrawn = true;
    // Draw a circle that lasts for 5 seconds.
    _debugDrawManager.addCircle(new vec3.raw(0.0, 0.0, 0.0),
                                new vec3.raw(0.0, 1.0, 0.0),
                                2.0,
                                new vec4.raw(1.0, 1.0, 1.0, 1.0),
                                5.0);
  }

  _drawSkybox();
  _drawCube();

  // Prepare the debug draw manager for rendering
  _debugDrawManager.prepareForRender();
  // Render it
  _debugDrawManager.render(camera);
}

// Handle resizes
void resizeFrame(GameLoop gameLoop) {
  CanvasElement canvas = gameLoop.element;
  // Set the canvas width and height to match the dom elements
  canvas.width = canvas.clientWidth;
  canvas.height = canvas.clientHeight;
  // Adjust the viewport dimensions
  _viewport.width = canvas.width;
  _viewport.height = canvas.height;
  // Fix the camera's aspect ratio
  camera.aspectRatio = canvas.width.toDouble()/canvas.height.toDouble();
}

void _setupSkybox() {
  _skyboxShaderProgram = _assetManager.root.demoAssets.skyBoxShader;
  assert(_skyboxShaderProgram.linked == true);
  _skyboxMesh = _assetManager.root.demoAssets.skyBox;
  _skyboxInputLayout = _graphicsDevice.createInputLayout('skybox.il');
  _skyboxInputLayout.mesh = _skyboxMesh;
  _skyboxInputLayout.shaderProgram = _skyboxShaderProgram;

  assert(_skyboxInputLayout.ready == true);
  _skyboxSampler = _graphicsDevice.createSamplerState('skybox.ss');
  _skyboxDepthState = _graphicsDevice.createDepthState('skybox.ds');
  _skyboxBlendState = _graphicsDevice.createBlendState('skybox.bs');
  _skyboxBlendState.enabled = false;
  _skyboxRasterizerState = _graphicsDevice.createRasterizerState('skybox.rs');
  _skyboxRasterizerState.cullMode = CullMode.None;
}

void _drawSkybox() {
  var context = _graphicsDevice.context;
  context.setInputLayout(_skyboxInputLayout);
  context.setPrimitiveTopology(GraphicsContext.PrimitiveTopologyTriangles);
  context.setShaderProgram(_skyboxShaderProgram);
  context.setTextures(0, [_assetManager.root.demoAssets.space]);
  context.setSamplers(0, [_skyboxSampler]);
  {
    mat4 P = camera.projectionMatrix;
    mat4 LA = makeLookAt(new vec3.zero(),
        camera.frontDirection,
        new vec3(0.0, 1.0, 0.0));
    P.multiply(LA);
    P.copyIntoArray(_cameraTransform, 0);
  }
  context.setConstant('cameraTransform', _cameraTransform);
  context.setBlendState(_skyboxBlendState);
  context.setRasterizerState(_skyboxRasterizerState);
  context.setDepthState(_skyboxDepthState);
  context.setIndexedMesh(_skyboxMesh);
  context.drawIndexedMesh(_skyboxMesh);
}

SingleArrayIndexedMesh _unitCubeMesh;
InputLayout _unitCubeInputLayout;
ShaderProgram _unitCubeShaderProgram;
RasterizerState _unitCubeRasterizerState;
DepthState _unitCubeDepthState;
Texture2D _unitCubeTexture;

void _setupCube() {
  _unitCubeShaderProgram = _assetManager.root.demoAssets.litdiffuse;
  _unitCubeMesh = _assetManager.root.demoAssets.unitCube;

  _unitCubeTexture = new Texture2D("unitCubeTexture", _graphicsDevice);
  _unitCubeTexture.uploadPixelArray(1, 1, new Uint8Array.fromList([0, 255, 255, 255]), pixelFormat: SpectreTexture.FormatRGBA, pixelType: SpectreTexture.PixelTypeU8);

  _unitCubeInputLayout = _graphicsDevice.createInputLayout('unitCube.il');
  _unitCubeInputLayout.mesh = _unitCubeMesh;
  _unitCubeInputLayout.shaderProgram = _unitCubeShaderProgram;

  _unitCubeRasterizerState = _graphicsDevice.createRasterizerState('unitCube.rs');
  _unitCubeRasterizerState.cullMode = CullMode.Back;

  _unitCubeDepthState = _graphicsDevice.createDepthState('unitCube.ds');
  _unitCubeDepthState.depthBufferEnabled = true;
  _unitCubeDepthState.depthBufferWriteEnabled = true;
  _unitCubeDepthState.depthBufferFunction = CompareFunction.LessEqual;
}


void _drawCube() {
  var context = _graphicsDevice.context;

  context.setPrimitiveTopology(GraphicsContext.PrimitiveTopologyTriangles);
  context.setShaderProgram(_unitCubeShaderProgram);
  //context.setTextures(0, [_assetManager.root.demoAssets.hellknight_body]);
  //context.clearColorBuffer(0, 255, 255, 0.2);
  context.setTextures(0, [_unitCubeTexture]);
  context.setSamplers(0, [_skyboxSampler]);

  mat4 P = camera.projectionMatrix;
  //print(P.getTranslation());
  P.setTranslation(new vec3(translateX, translateY, translateZ));
  //print(P.getTranslation());
  mat4 LA = camera.lookAtMatrix;
  P.multiply(LA);
  P.copyIntoArray(_cameraTransform, 0);

  context.setConstant('cameraTransform', _cameraTransform);
  //context.setConstant('objectTransform', _unitCubeTransform);
  context.setBlendState(_skyboxBlendState);
  context.setRasterizerState(_unitCubeRasterizerState);
  context.setDepthState(_unitCubeDepthState);
  //context.setIndexBuffer(_unitCubeMesh.indexArray);
  //context.setVertexBuffers(0, [_unitCubeMesh.vertexArray]);
  context.setInputLayout(_unitCubeInputLayout);

  context.setIndexedMesh(_unitCubeMesh);
  context.drawIndexedMesh(_unitCubeMesh);

}

void main() {

  // TODO(adam): must be a better way to get base url from location.
  final String baseUrl = "${window.location.href.substring(0, window.location.href.length - "spectre_cube.html".length)}";
  print(baseUrl);
  CanvasElement canvas = query(_canvasId);
  assert(canvas != null);


  // Create a GraphicsDevice
  _graphicsDevice = new GraphicsDevice(canvas);
  // Print out GraphicsDeviceCapabilities
  print(_graphicsDevice.capabilities);
  // Get a reference to the GraphicsContext
  _graphicsContext = _graphicsDevice.context;
  // Create a debug draw manager and initialize it
  _debugDrawManager = new DebugDrawManager(_graphicsDevice);

  // Set the canvas width and height to match the dom elements
  canvas.width = canvas.clientWidth;
  canvas.height = canvas.clientHeight;

  // Create the viewport
  _viewport = _graphicsDevice.createViewport('view');
  _viewport.x = 0;
  _viewport.y = 0;
  _viewport.width = canvas.width;
  _viewport.height = canvas.height;

  // Create the camera
  camera.aspectRatio = canvas.width.toDouble()/canvas.height.toDouble();
  camera.position = new vec3.raw(2.0, 2.0, 2.0);
  camera.focusPosition = new vec3.raw(1.0, 1.0, 1.0);

  _assetManager = new AssetManager();
  registerSpectreWithAssetManager(_graphicsDevice, _assetManager);

  _gameLoop = new GameLoop(canvas);
  _gameLoop.onUpdate = gameFrame;
  _gameLoop.onRender = renderFrame;
  _gameLoop.onResize = resizeFrame;
  _assetManager.loadPack('demoAssets', '$baseUrl/assets.pack').then((assetPack) {
    // All assets are loaded.
    _setupSkybox();
    _setupCube();
    _gameLoop.start();
  });


}
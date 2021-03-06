package;
import js.html.Float32Array;
import js.html.CanvasElement;
import js.html.webgl.RenderingContext;
import js.html.webgl.Program;
import js.html.webgl.Shader;
import js.Browser;
import js.html.Uint16Array;
import js.html.StyleElement;
import js.html.ImageElement;
import js.html.Image;
import HaxeLogo;
import khaMath.Matrix4;
import justTriangles.Triangle;
import justTriangles.Draw;
import justTriangles.Point;
import justTriangles.PathContext;
import justTriangles.ShapePoints;
import justTriangles.QuickPaths;
import htmlHelper.tools.CSSEnterFrame;
import justTriangles.SvgPath;
import justTriangles.PathContextTrace;
using Test;
class Test {
    public static inline var vertexString: String =
        'attribute vec3 pos;' +
        'attribute vec2 aTexture;' +
        'varying vec2 texture;' +
        'uniform mat4 modelViewProjection;' +
        'void main(void) {' + 
            ' gl_Position = modelViewProjection * vec4( pos, 1.0);' +
            ' texture = vec2( aTexture.x , 1.-aTexture.y );' +
        '}';
    
    public static inline var fragmentString: String =
        'precision mediump float;' +
        'uniform sampler2D image;' +
        'varying vec2 texture;' +
        'void main(void) {' +
            'float bound =   step( texture.s, 1. ) *' +
                            'step( texture.t, 1. ) *' +
                            ' ( 1. - step( texture.s, 0. ) ) * '+
                            ' ( 1. - step( texture.t, 0. ) );'+
            'gl_FragColor = bound * texture2D( image, vec2( texture.s, texture.t ) );'+
        '}'; 
    
    public static inline function ident(): Array<Float> {
        return [ 1.0, 0.0, 0.0, 0.0,
                 0.0, 1.1, 0.0, 0.0,
                 0.0, 0.0, 1.0, 0.0,
                 0.0, 0.0, 0.0, 1.0
                 ];
    }
    // converts from our internal representation of a matrix to the Float32Array that webgl uses.
    public static inline function transferM4_arr32( arr: Float32Array, m: Matrix4 ) {
        arr.set([ m._00, m._10, m._20, m._30, m._01, m._11, m._21, m._31, m._02, m._12, m._22, m._32, m._03, m._13, m._23, m._33 ]);
    }
    static function main(){
        Draw.drawTri = Triangle.drawTri;
        new Test();
    }
    public static inline var width: Int = 800;
    public static inline var height: Int = 800;
    var canvas: CanvasElement;
    var gl: RenderingContext;
    var program: Program;
    var vertices = new Array<Float>();
    var texturePos = new Array<Float>();
    var indices = new Array<Int>();
    var theta = 0.0; // Angle in radians
    var modelViewProjection = Matrix4.identity(); // external matrix controlling global 3d position
    var matrix32Array = new Float32Array( ident() ); // internal matrix passed to shader
    public function new(){
        gl = createWebGl( width, height );
        // 'using' allows us to put gl in front of the function making the code more descriptive
        var vertex = gl.createShaderFromString( RenderingContext.VERTEX_SHADER, vertexString );
        var fragment = gl.createShaderFromString( RenderingContext.FRAGMENT_SHADER, fragmentString );
        program = gl.createShaderProgram( vertex, fragment );
        var thick = 4;
        var ctx = new PathContext( 1, 1000, 0, 0 );
        ctx.setColor( 2, 2 );
        ctx.setThickness( thick*5 );
        ctx.lineType = TriangleJoinCurve; // - default
        var pathTrace = new PathContextTrace();
        var p = new SvgPath( ctx );
        p.parse( bird_d, 0, 0, 3, 3 );
        ctx.render( thick, false ); 
        ctx.setThickness( thick );
        var x0: Float = 0.;
        var y0: Float = 0.;
        for( i in 0...Std.int( 2000/30 ) ){
            ctx.moveTo( x0, y0 );
            ctx.lineTo( 2000., y0 );
            y0+=30;
        }
        ctx.render( thick, false ); 
        loadImage( HaxeLogo.gif ); // MUST BE SAME DOMAIN!!!
    }
    function loadImage( imgStr: String ){
        var img: Image = untyped __js__( "new Image()" );
        img.style.left = '0px';
        img.style.top = '0px';
        img.onload = store.bind( img );
        img.style.position = "absolute";
        img.src = imgStr;
    }
    function store( img: Image, e ){
        //Browser.document.body.appendChild( img );
        setTriangleImage( Triangle.triangles, img );
        injectCSSenterFrame();
    }
    // rather ugly way to inject add a css enterframe loop for animation into the head of document.
    function injectCSSenterFrame(){
        var s = Browser.document.createStyleElement();
        s.innerHTML = "@keyframes spin { from { transform:rotate( 0deg ); } to { transform:rotate( 360deg ); } }";
        Browser.document.getElementsByTagName("head")[0].appendChild( s );
        (cast s).animation = "spin 1s linear infinite";
        loop( 60.0 );
    }
    function loop( tim: Float ): Bool {
        Browser.window.requestAnimationFrame( loop );
        onFrame();
        return true;
    }
    // called every frame, sets transform and redraws
    function onFrame(){
        // we can multiply two rotations to get an interesting movement of the static 2D triangles.
        modelViewProjection = Matrix4.identity();
        modelViewProjection = Matrix4.rotationZ( theta += Math.PI/100 ).multmat( Matrix4.rotationY( theta ) ); // Remove this line to stop 3D rotation
        render();
    }
    function createWebGl( width_: Int, height_: Int ): RenderingContext {
        canvas = Browser.document.createCanvasElement();
        canvas.width = width;
        canvas.height = height;
        var dom = cast canvas;
        var style = dom.style;
        style.paddingLeft = "0px";
        style.paddingTop = "0px";
        style.left = '0px';
        style.top = '0px';
        style.position = "absolute";
        Browser.document.body.appendChild( cast canvas );
        var gl = canvas.getContextWebGL( { 'antialias': true } );
        return gl;
    }
    static inline function createShaderProgram( gl: RenderingContext, vertex: Shader, fragment: Shader ): Program {
        var program = gl.createProgram();
        gl.attachShader( program, vertex );
        gl.attachShader( program, fragment );
        gl.linkProgram( program );
        gl.useProgram( program );
        return program;
    }
    // used for generating fragment and vertex shaders from strings
    static inline function createShaderFromString( gl: RenderingContext, shaderType: Int, shaderString: String ): Shader {
        var shader = gl.createShader( shaderType );
        gl.shaderSource( shader, shaderString ); 
        gl.compileShader( shader );
        return shader;
    }
    function setTriangleImage( triangles: Array<Triangle>, image: Image ) {
        var tri: Triangle;
        var count = 0;
        for( i in 0...triangles.length ){
            tri = triangles[ i ];
            vertices.push( tri.ax - 0.5 );
            texturePos.push( tri.ax );
            vertices.push( -tri.ay + 0.5 );
            texturePos.push( tri.ay );
            vertices.push( tri.depth );
            vertices.push( tri.bx - 0.5 );
            texturePos.push( tri.bx );
            vertices.push( -tri.by + 0.5 );
            texturePos.push( tri.by );
            vertices.push( tri.depth );
            vertices.push( tri.cx - 0.5 );
            texturePos.push( tri.cx );
            vertices.push( -tri.cy + 0.5 );
            texturePos.push( tri.cy );
            vertices.push( tri.depth );
            for( k in 0...3 ) indices.push( count++ );
        } 
        gl.passAttributeToShader( program, 'pos', 3, vertices ); // position data
        gl.passIndicesToShader( indices ); // indices data 
        gl.uploadImage( program, image, texturePos ); // image data
    }
    static inline function uploadImage( gl: RenderingContext, program: Program, image: Image, texturePos: Array<Float> ){
        var texCoordLocation = gl.getAttribLocation(program, "aTexture");
        var texCoordBuffer = gl.createBuffer();
        gl.bindBuffer( RenderingContext.ARRAY_BUFFER, texCoordBuffer);
        gl.bufferData( RenderingContext.ARRAY_BUFFER, new Float32Array( texturePos ), RenderingContext.STATIC_DRAW );
        gl.enableVertexAttribArray( texCoordLocation);
        gl.vertexAttribPointer( texCoordLocation, 2, RenderingContext.FLOAT, false, 0, 0 );
        var texture = gl.createTexture();
        gl.activeTexture( RenderingContext.TEXTURE0 );
        gl.bindTexture( RenderingContext.TEXTURE_2D, texture );
        gl.pixelStorei( RenderingContext.UNPACK_FLIP_Y_WEBGL, 1 );
        gl.texParameteri( RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_WRAP_S, RenderingContext.CLAMP_TO_EDGE );
        gl.texParameteri( RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_WRAP_T, RenderingContext.CLAMP_TO_EDGE );
        gl.texParameteri( RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.NEAREST );
        gl.texParameteri( RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MAG_FILTER, RenderingContext.NEAREST );
        gl.texImage2D( RenderingContext.TEXTURE_2D, 0, RenderingContext.RGBA, RenderingContext.RGBA, RenderingContext.UNSIGNED_BYTE, image );
    }
    static inline function passIndicesToShader( gl: RenderingContext, indices: Array<Int> ){
        var indexBuffer = gl.createBuffer(); // triangle indicies data 
        gl.bindBuffer( RenderingContext.ELEMENT_ARRAY_BUFFER, indexBuffer );
        gl.bufferData( RenderingContext.ELEMENT_ARRAY_BUFFER, new Uint16Array( indices ), RenderingContext.STATIC_DRAW );
        gl.bindBuffer( RenderingContext.ELEMENT_ARRAY_BUFFER, null );
    }
    // generic passing attributes to shader.
    static inline function passAttributeToShader( gl: RenderingContext, program: Program, name: String, att: Int, arr: Array<Float> ){
        var floatBuffer = gl.createBuffer();
        gl.bindBuffer( RenderingContext.ARRAY_BUFFER, floatBuffer );
        gl.bufferData( RenderingContext.ARRAY_BUFFER, new Float32Array( arr ), RenderingContext.STATIC_DRAW );
        var flo = gl.getAttribLocation( program, name );
        gl.vertexAttribPointer( flo, att, RenderingContext.FLOAT, false, 0, 0 ); 
        gl.enableVertexAttribArray( flo );
        gl.bindBuffer( RenderingContext.ARRAY_BUFFER, null );
    }
    function render(){
        // setup and clear
        gl.clearColor( 0.5, 0.0, 0.5, 0.9 );
        gl.enable( RenderingContext.DEPTH_TEST );
        gl.clear( RenderingContext.COLOR_BUFFER_BIT );
        gl.viewport( 0, 0, canvas.width, canvas.height );
        // apply transform matrices 
        var modelViewProjectionID = gl.getUniformLocation( program, 'modelViewProjection' );
        transferM4_arr32( matrix32Array, modelViewProjection );    
        gl.uniformMatrix4fv( modelViewProjectionID, false, matrix32Array );
        // draw
        gl.drawArrays( RenderingContext.TRIANGLES, 0, indices.length );
    }
    var quadtest_d = "M200,300 Q400,50 600,300 T1000,300";
    var cubictest_d = "M100,200 C100,100 250,100 250,200S400,300 400,200";
    var bird_d = "M210.333,65.331C104.367,66.105-12.349,150.637,1.056,276.449c4.303,40.393,18.533,63.704,52.171,79.03c36.307,16.544,57.022,54.556,50.406,112.954c-9.935,4.88-17.405,11.031-19.132,20.015c7.531-0.17,14.943-0.312,22.59,4.341c20.333,12.375,31.296,27.363,42.979,51.72c1.714,3.572,8.192,2.849,8.312-3.078c0.17-8.467-1.856-17.454-5.226-26.933c-2.955-8.313,3.059-7.985,6.917-6.106c6.399,3.115,16.334,9.43,30.39,13.098c5.392,1.407,5.995-3.877,5.224-6.991c-1.864-7.522-11.009-10.862-24.519-19.229c-4.82-2.984-0.927-9.736,5.168-8.351l20.234,2.415c3.359,0.763,4.555-6.114,0.882-7.875c-14.198-6.804-28.897-10.098-53.864-7.799c-11.617-29.265-29.811-61.617-15.674-81.681c12.639-17.938,31.216-20.74,39.147,43.489c-5.002,3.107-11.215,5.031-11.332,13.024c7.201-2.845,11.207-1.399,14.791,0c17.912,6.998,35.462,21.826,52.982,37.309c3.739,3.303,8.413-1.718,6.991-6.034c-2.138-6.494-8.053-10.659-14.791-20.016c-3.239-4.495,5.03-7.045,10.886-6.876c13.849,0.396,22.886,8.268,35.177,11.218c4.483,1.076,9.741-1.964,6.917-6.917c-3.472-6.085-13.015-9.124-19.18-13.413c-4.357-3.029-3.025-7.132,2.697-6.602c3.905,0.361,8.478,2.271,13.908,1.767c9.946-0.925,7.717-7.169-0.883-9.566c-19.036-5.304-39.891-6.311-61.665-5.225c-43.837-8.358-31.554-84.887,0-90.363c29.571-5.132,62.966-13.339,99.928-32.156c32.668-5.429,64.835-12.446,92.939-33.85c48.106-14.469,111.903,16.113,204.241,149.695c3.926,5.681,15.819,9.94,9.524-6.351c-15.893-41.125-68.176-93.328-92.13-132.085c-24.581-39.774-14.34-61.243-39.957-91.247c-21.326-24.978-47.502-25.803-77.339-17.365c-23.461,6.634-39.234-7.117-52.98-31.273C318.42,87.525,265.838,64.927,210.333,65.331zM445.731,203.01c6.12,0,11.112,4.919,11.112,11.038c0,6.119-4.994,11.111-11.112,11.111s-11.038-4.994-11.038-11.111C434.693,207.929,439.613,203.01,445.731,203.01z";
}
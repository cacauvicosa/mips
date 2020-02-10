const path = require('path');
const CleanWebpackPlugin = require("clean-webpack-plugin");

module.exports = {
    mode: 'development',
    devtool: 'source-map',
    entry: './index.ts',
    context: path.resolve(__dirname, 'src'),
    output: {
        path: path.resolve(__dirname, 'dist'),
        filename: 'wavecanvas.js',
        library: 'wavecanvas',
        libraryTarget: 'umd',
        umdNamedDefine: true,
        globalObject: 'this'
    },
    resolve: {
        extensions: ['.ts', '.tsx', '.js']
    },
    module: {
        rules: [
            {
                test: /\.tsx?$/,
                loader: 'ts-loader'
            }
        ]
    },
    plugins: [
        new CleanWebpackPlugin(['dist'])
    ]
};


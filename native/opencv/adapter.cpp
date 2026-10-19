// Universal Studio Toolkit's narrow pixel-only OpenCV adapter (project MIT).
// No file, camera, network, model, scripting or image-codec entry points.
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/geometry.hpp>
#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <vector>
#if defined(_WIN32)
#define UST_EXPORT extern "C" __declspec(dllexport)
#else
#define UST_EXPORT extern "C" __attribute__((visibility("default")))
#endif
namespace {
constexpr uint64_t max_pixels = 24000000;
bool dimensions(uint32_t width, uint32_t height, size_t length) {
    return width >= 2 && height >= 2 && width <= 12000 && height <= 12000 &&
        uint64_t(width) * height <= max_pixels && uint64_t(width) * height * 4 == length;
}
bool quad_valid(const double* xy) {
    double area = 0;
    for (size_t i = 0; i < 4; ++i) {
        const size_t next = (i + 1) % 4, last = (i + 2) % 4;
        const double x = xy[2*i], y = xy[2*i+1];
        if (!std::isfinite(x) || !std::isfinite(y) || x < 0 || y < 0 || x > 1 || y > 1) return false;
        const double ax = xy[2*next]-x, ay = xy[2*next+1]-y;
        const double bx = xy[2*last]-xy[2*next], by = xy[2*last+1]-xy[2*next+1];
        if (ax*by-ay*bx <= 0.000001) return false;
        area += x*xy[2*next+1]-xy[2*next]*y;
    }
    return area >= 0.02; // At least one percent of the oriented source area.
}
}
UST_EXPORT uint32_t ust_cv_abi_version() { return 1; }
UST_EXPORT uint32_t ust_cv_engine_version() {
    return CV_VERSION_MAJOR*10000 + CV_VERSION_MINOR*100 + CV_VERSION_REVISION;
}
// Return 0 on success, 2 for invalid arguments, 3 for an engine/allocation failure.
UST_EXPORT int32_t ust_cv_warp_rgba(const uint8_t* input, uint32_t width, uint32_t height,
        size_t input_length, const double* corners, size_t corner_count,
        uint8_t* output, uint32_t output_width, uint32_t output_height, size_t output_length) {
    if (!input || !output || !corners || corner_count != 8 ||
        !dimensions(width, height, input_length) ||
        !dimensions(output_width, output_height, output_length) || !quad_valid(corners)) return 2;
    try {
        cv::setNumThreads(1);
        const cv::Mat source(int(height), int(width), CV_8UC4, const_cast<uint8_t*>(input));
        cv::Mat destination(int(output_height), int(output_width), CV_8UC4, output);
        std::array<cv::Point2f, 4> from, to = {{{0,0}, {float(output_width-1),0},
            {float(output_width-1),float(output_height-1)}, {0,float(output_height-1)}}};
        for (size_t i=0; i<4; ++i) from[i] = cv::Point2f(float(corners[2*i]*(width-1)), float(corners[2*i+1]*(height-1)));
        const auto transform = cv::getPerspectiveTransform(from.data(), to.data());
        if (!cv::checkRange(transform)) return 2;
        cv::warpPerspective(source, destination, transform, destination.size(), cv::INTER_LINEAR,
            cv::BORDER_CONSTANT, cv::Scalar(255,255,255,255));
        return 0;
    } catch (...) { return 3; }
}
// Suggestions are advisory and never applied automatically. 1 means none found.
UST_EXPORT int32_t ust_cv_suggest_rgba(const uint8_t* input, uint32_t width, uint32_t height,
        size_t input_length, double* corners, size_t corner_count) {
    if (!input || !corners || corner_count != 8 || !dimensions(width, height, input_length)) return 2;
    try {
        cv::setNumThreads(1);
        const cv::Mat source(int(height), int(width), CV_8UC4, const_cast<uint8_t*>(input));
        cv::Mat resized, gray, edges;
        const double scale = std::min(1.0, 1000.0 / std::max(width, height));
        cv::resize(source, resized, cv::Size(std::max(2,int(std::round(width*scale))),
            std::max(2,int(std::round(height*scale)))), 0, 0, cv::INTER_AREA);
        cv::cvtColor(resized, gray, cv::COLOR_RGBA2GRAY);
        cv::GaussianBlur(gray, gray, cv::Size(5,5), 0);
        cv::Canny(gray, edges, 75, 200);
        std::vector<std::vector<cv::Point>> contours;
        cv::findContours(edges, contours, cv::RETR_LIST, cv::CHAIN_APPROX_SIMPLE);
        double largest = resized.total()*0.1;
        std::vector<cv::Point> selected;
        for (const auto& contour : contours) {
            const double area = std::abs(cv::contourArea(contour));
            if (area <= largest) continue;
            std::vector<cv::Point> polygon;
            cv::approxPolyDP(contour, polygon, 0.02*cv::arcLength(contour, true), true);
            if (polygon.size() != 4 || !cv::isContourConvex(polygon)) continue;
            largest=area; selected=std::move(polygon);
        }
        if (selected.empty()) return 1;
        cv::Point2d centre(0,0);
        for (const auto& p : selected) { centre.x += p.x/4.; centre.y += p.y/4.; }
        std::sort(selected.begin(), selected.end(), [&centre](const auto& a, const auto& b) {
            return std::atan2(a.y-centre.y,a.x-centre.x) < std::atan2(b.y-centre.y,b.x-centre.x);
        });
        const auto first=std::min_element(selected.begin(),selected.end(),[](const auto& a,const auto& b) {
            if(a.x+a.y!=b.x+b.y) return a.x+a.y < b.x+b.y;
            return a.y < b.y;
        });
        std::rotate(selected.begin(),first,selected.end());
        for(size_t i=0;i<4;++i) {
            corners[2*i]=std::clamp(double(selected[i].x)/(resized.cols-1),0.,1.);
            corners[2*i+1]=std::clamp(double(selected[i].y)/(resized.rows-1),0.,1.);
        }
        return quad_valid(corners) ? 0 : 1;
    } catch (...) { return 3; }
}

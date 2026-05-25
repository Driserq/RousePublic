"use client";

import { useEffect, useRef } from "react";

interface ZenRingProps {
  className?: string;
  color?: string; // Hex or rgba
}

export default function ZenRing({ className, color = "#00f0ff" }: ZenRingProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let animationFrameId: number;
    let time = 0;

    // Configuration matching the Swift "EnergyRing" logic
    // We will render 3 layers: Atmosphere, Plasma, Core
    const layers = [
      {
        frequency: 3,
        amplitude: 0.05, // reduced amplitude relative to canvas size
        phaseShift: 0,
        blur: 15,
        lineWidth: 20,
        opacity: 0.3,
        color: color,
      },
      {
        frequency: 3,
        amplitude: 0.05,
        phaseShift: 1.5,
        blur: 4,
        lineWidth: 6,
        opacity: 0.8,
        color: color,
      },
      {
        frequency: 8, // Core is faster/buzzier
        amplitude: 0.03,
        phaseShift: 3.0,
        blur: 0.5,
        lineWidth: 2,
        opacity: 0.9,
        color: "#ffffff",
      },
    ];

    const resize = () => {
      const parent = canvas.parentElement;
      if (parent) {
        canvas.width = parent.clientWidth * window.devicePixelRatio;
        canvas.height = parent.clientHeight * window.devicePixelRatio;
        canvas.style.width = `${parent.clientWidth}px`;
        canvas.style.height = `${parent.clientHeight}px`;
        ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
      }
    };

    window.addEventListener("resize", resize);
    resize();

    const drawPath = (
      layer: (typeof layers)[0],
      radius: number,
      centerX: number,
      centerY: number,
      t: number
    ) => {
      ctx.beginPath();
      const points = 200; // Resolution
      const angleStep = (Math.PI * 2) / points;

      for (let i = 0; i <= points; i++) {
        const angle = i * angleStep;

        // Matches Swift: sin(angle * frequency + phaseShift)
        const mainWave = Math.sin(angle * layer.frequency + layer.phaseShift);

        // Matches Swift: cos(angle * (freq * 2.0) - time * 2.0) * 0.5
        // Note: We use t (time) to animate
        const noise =
          Math.cos(angle * (layer.frequency * 2.0) - t * 2.0) * 0.5;

        // Distortion amount
        const distortion = (mainWave + noise) * (radius * layer.amplitude);

        const r = radius + distortion;
        const x = centerX + Math.cos(angle) * r;
        const y = centerY + Math.sin(angle) * r;

        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      
      ctx.closePath();
      
      // Styling
      ctx.shadowBlur = layer.blur;
      ctx.shadowColor = layer.color;
      ctx.strokeStyle = `rgba(${hexToRgb(layer.color)}, ${layer.opacity})`;
      
      // To handle hex colors with alpha properly in strokeStyle if needed, 
      // but simplistic approach here:
      if (layer.color.startsWith("#")) {
         // Apply opacity via globalAlpha or parsed color. 
         // Let's rely on shadow for glow and stroke for line.
         ctx.strokeStyle = hexToRgba(layer.color, layer.opacity);
         ctx.shadowColor = layer.color;
      }
      
      ctx.lineWidth = layer.lineWidth;
      ctx.lineCap = "round";
      ctx.lineJoin = "round";
      ctx.stroke();
    };

    const render = () => {
      if (!canvas || !ctx) return;
      
      // Clear
      const width = canvas.width / window.devicePixelRatio;
      const height = canvas.height / window.devicePixelRatio;
      ctx.clearRect(0, 0, width, height);

      // Add composite operation for "screen" blend mode effect if desired
      // ctx.globalCompositeOperation = "screen"; // Can be expensive/tricky in 2D canvas

      const centerX = width / 2;
      const centerY = height / 2;
      const radius = Math.min(width, height) / 2 * 0.8; // 80% of container

      time += 0.01; // Animation speed

      layers.forEach((layer) => {
        drawPath(layer, radius, centerX, centerY, time);
      });

      animationFrameId = requestAnimationFrame(render);
    };

    render();

    return () => {
      window.removeEventListener("resize", resize);
      cancelAnimationFrame(animationFrameId);
    };
  }, [color]);

  return <canvas ref={canvasRef} className={className} />;
}

// Helpers
function hexToRgb(hex: string) {
  // Expand shorthand form (e.g. "03F") to full form (e.g. "0033FF")
  const shorthandRegex = /^#?([a-f\d])([a-f\d])([a-f\d])$/i;
  hex = hex.replace(shorthandRegex, (m, r, g, b) => {
    return r + r + g + g + b + b;
  });

  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result
    ? `${parseInt(result[1], 16)}, ${parseInt(result[2], 16)}, ${parseInt(
        result[3],
        16
      )}`
    : "0, 240, 255"; // Default Neon Blue
}

function hexToRgba(hex: string, alpha: number) {
    const rgb = hexToRgb(hex);
    return `rgba(${rgb}, ${alpha})`;
}

package com.stepuphub.dto;

/** Outcome of cancelling a slot series: how many slots were cancelled, kept (booked), and how many of the cancelled ones were booked. */
public record SeriesCancelResultDto(int cancelled, int keptBooked, int bookedCancelled) {}
